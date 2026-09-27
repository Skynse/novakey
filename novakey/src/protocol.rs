//! NovaKey host protocol over a dedicated 32-byte raw-HID interface.
//!
//! This is a faithful port of the QMK `raw_hid_receive` handler and the
//! `0x40` control-event stream that NovaKey Studio speaks. The interface uses
//! usage page `0xFF60`, usage `0x4B`, and unnumbered 32-byte IN/OUT reports,
//! exactly as the QMK descriptor did, so the existing desktop app keeps
//! working unchanged.

use embassy_futures::select::{Either, select};
use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_sync::channel::Channel;
use embassy_time::{Duration, Instant, Timer};
use embassy_usb::class::hid::{HidReader, HidWriter};
use embassy_usb::driver::{Driver, EndpointError};

use crate::output;
use crate::state::{
    self, FLASH_PAGE_SIZE, FLASH_SECTOR_SIZE, MAPPING_BYTES, MAPPING_FLASH_OFFSET, with_state,
};

/// USB report descriptor: Usage Page 0xFF60, Usage 0x4B, application
/// collection with a 32-byte input (0x62) and 32-byte output (0x63) report.
/// Byte-for-byte identical to QMK's `RawReport`.
pub const REPORT_DESCRIPTOR: &[u8] = &[
    0x06, 0x60, 0xFF, // Usage Page (0xFF60)
    0x09, 0x4B, // Usage (0x4B)
    0xA1, 0x01, // Collection (Application)
    0x09, 0x62, //   Usage (0x62)
    0x15, 0x00, //   Logical Minimum (0)
    0x26, 0xFF, 0x00, //   Logical Maximum (255)
    0x95, 0x20, //   Report Count (32)
    0x75, 0x08, //   Report Size (8)
    0x81, 0x02, //   Input (Data, Variable, Absolute)
    0x09, 0x63, //   Usage (0x63)
    0x15, 0x00, //   Logical Minimum (0)
    0x26, 0xFF, 0x00, //   Logical Maximum (255)
    0x95, 0x20, //   Report Count (32)
    0x75, 0x08, //   Report Size (8)
    0x91, 0x06, //   Output (Data, Variable, Absolute, Non-Volatile)
    0xC0, // End Collection
];

/// Outgoing HID reports (command replies and `0x40` control events).
pub static HID_TX: Channel<CriticalSectionRawMutex, [u8; 32], 16> = Channel::new();

/// Flash capacity of the RP2040 part.
pub const FLASH_SIZE: usize = 2 * 1024 * 1024;

/// Blocking flash handle used for the onboard profile.
pub type FlashStorage = embassy_rp::flash::Flash<
    'static,
    embassy_rp::peripherals::FLASH,
    embassy_rp::flash::Blocking,
    FLASH_SIZE,
>;

/// Build the `0x40` control event the app receives for every physical control.
pub fn control_event(id: u8, pressed: bool, repeat: u8) -> [u8; 32] {
    let mut event = [0u8; 32];
    event[0] = b'N';
    event[1] = b'K';
    event[2] = 0x40;
    event[4] = id;
    event[5] = pressed as u8;
    event[6] = repeat;
    event
}

/// Read and decode the persisted onboard profile, if present.
pub fn load_mapping(flash: &mut FlashStorage) {
    let mut buffer = [0u8; FLASH_PAGE_SIZE];
    if flash
        .blocking_read(MAPPING_FLASH_OFFSET, &mut buffer)
        .is_ok()
        && let Some(mapping) = state::decode_mapping(&buffer)
    {
        with_state(|state| state.mapping = mapping);
    }
}

fn save_mapping(flash: &mut FlashStorage) {
    let mut page = [0xFFu8; FLASH_PAGE_SIZE];
    page[0] = state::MAPPING_MAGIC[0];
    page[1] = state::MAPPING_MAGIC[1];
    let mut encoded = [0u8; MAPPING_BYTES];
    with_state(|state| state::encode_mapping(&state.mapping, &mut encoded));
    page[2..2 + MAPPING_BYTES].copy_from_slice(&encoded);

    let _ = flash.blocking_erase(
        MAPPING_FLASH_OFFSET,
        MAPPING_FLASH_OFFSET + FLASH_SECTOR_SIZE,
    );
    let _ = flash.blocking_write(MAPPING_FLASH_OFFSET, &page);
}

fn lease_expired() {
    let expired = with_state(|state| {
        if state.captured && state.heartbeat.elapsed().as_millis() > 3000 {
            state.captured = false;
            state.clear_held();
            true
        } else {
            false
        }
    });
    if expired {
        output::release_all();
    }
}

fn handle_packet(data: &mut [u8; 32], flash: &mut FlashStorage) -> bool {
    if data[0] != b'N' || data[1] != b'K' {
        return false;
    }

    let now = Instant::now();
    let mut status = 0u8;
    let mut enter_bootloader = false;

    match data[2] {
        0x01 => {
            with_state(|state| state.heartbeat = now);
        }
        0x02 => {
            data[4] = 2; // protocol version
            data[5] = 16; // number of matrix keys
            data[6] = 3; // number of encoders
            data[7] = state::NUM_CONTROLS as u8;
        }
        0x10 => {
            output::release_all();
            let capture = data[4] == 1;
            with_state(|state| {
                state.captured = capture;
                state.heartbeat = now;
                state.clear_held();
            });
        }
        0x11 => {
            let code = data[4] as u16 | (((data[5] & 0x0f) as u16) << 8);
            let down = data[6] == 1;
            let allowed = data[6] <= 1;
            if !allowed || !with_state(|state| state.captured) {
                status = 2;
            } else {
                output::emit(code, down);
                with_state(|state| state.heartbeat = now);
            }
        }
        0x12 => {
            output::release_all();
        }
        0x20 => {
            with_state(|state| {
                state.staged_mask = 0;
                state.staged = [0; state::NUM_CONTROLS];
            });
        }
        0x21 => {
            let index = data[4];
            let value = data[5] as u16 | ((data[6] as u16) << 8);
            if index as usize >= state::NUM_CONTROLS || data[6] > 15 {
                status = 2;
            } else {
                with_state(|state| {
                    state.staged[index as usize] = value;
                    state.staged_mask |= 1 << index;
                });
            }
        }
        0x22 => {
            let staged_mask = with_state(|state| state.staged_mask);
            if staged_mask != 0x01ff_ffff {
                status = 2;
            } else {
                output::release_all();
                with_state(|state| {
                    state.mapping = state.staged;
                    state.clear_held();
                    state.staged_mask = 0;
                });
                save_mapping(flash);
            }
        }
        0x30 => {
            // Guard this destructive command with a magic payload so random
            // vendor-HID traffic cannot unexpectedly reboot the pad.
            if data[4..8] == *b"BOOT" {
                output::release_all();
                enter_bootloader = true;
            } else {
                status = 2;
            }
        }
        0x31 => {
            let requested = data[4];
            if requested != 0xff && requested >= crate::animations::MODE_COUNT {
                status = 2;
            } else {
                with_state(|state| {
                    if requested != 0xff {
                        state.animation_mode = requested;
                        state.last_activity = now;
                    }
                    data[4] = state.animation_mode;
                    data[5] = crate::animations::MODE_COUNT;
                });
            }
        }
        _ => status = 1,
    }

    data[3] = status;
    let _ = HID_TX.try_send(*data);
    enter_bootloader
}

/// Reader task: serve host commands and enforce the capture lease.
pub async fn run_reader<D: Driver<'static>>(
    mut reader: HidReader<'static, D, 32>,
    mut flash: FlashStorage,
) -> ! {
    let mut buffer = [0u8; 32];
    loop {
        match select(
            reader.read(&mut buffer),
            Timer::after(Duration::from_millis(1000)),
        )
        .await
        {
            Either::First(Ok(32)) => {
                if handle_packet(&mut buffer, &mut flash) {
                    // Give the independent HID writer enough time to deliver
                    // the acknowledgement before the USB peripheral resets.
                    Timer::after(Duration::from_millis(150)).await;
                    embassy_rp::rom_data::reset_to_usb_boot(0, 0);
                }
            }
            Either::First(_) => {}
            Either::Second(_) => lease_expired(),
        }
    }
}

/// Writer task: drain queued reports to the host.
pub async fn run_writer<D: Driver<'static>>(mut writer: HidWriter<'static, D, 32>) -> ! {
    loop {
        let packet = HID_TX.receive().await;
        if let Err(_error) = writer.write(&packet).await {
            // Host not draining the endpoint; drop the report.
        }
    }
}

#[allow(dead_code)]
fn _assert_endpoint_error(_error: EndpointError) {}
