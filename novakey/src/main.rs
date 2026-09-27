#![no_main]
#![no_std]

mod animations;
mod buttons;
mod control;
mod encoders;
mod keymap;
mod output;
mod protocol;
mod renderer;
mod state;

use defmt_rtt as _;
use embassy_executor::Spawner;
use embassy_futures::join::{join, join3, join5};
use embassy_rp::bind_interrupts;
use embassy_rp::flash::{Blocking, Flash};
use embassy_rp::gpio::{Input, Level, Output, Pull};
use embassy_rp::i2c::{self, I2c};
use embassy_rp::peripherals::{I2C1, USB};
use embassy_rp::usb::{Driver, InterruptHandler};
use embassy_rp::watchdog::Watchdog;
use keymap::{COL, ROW};
use panic_probe as _;
use rmk::config::{BehaviorConfig, DeviceConfig, PositionalConfig};
use rmk::core_traits::Runnable;
use rmk::debounce::default_debouncer::DefaultDebouncer;
use rmk::display::ssd1306::{I2CDisplayInterface, Ssd1306Async, prelude::*};
use rmk::keyboard::Keyboard;
use rmk::matrix::Matrix;
use rmk::usb::UsbTransport;
use rmk::watchdog::Rp2040Watchdog;
use rmk::{KeymapData, initialize_keymap};

use buttons::EncoderButtons;
use control::ControlProcessor;
use encoders::Encoders;
use output::Emitter;
use protocol::FLASH_SIZE;
use renderer::OledDisplay;

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => InterruptHandler<USB>;
    I2C1_IRQ => i2c::InterruptHandler<I2C1>;
});

/// Interrupt-free display bus address.
const OLED_ADDRESS: u8 = 0x3C;

#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    let p = embassy_rp::init(Default::default());

    // ---- Keymap ---------------------------------------------------------
    let mut keymap_data =
        KeymapData::new_with_encoder(keymap::default_keymap(), keymap::default_encoder_map());
    let mut behavior = BehaviorConfig::default();
    let positional = PositionalConfig::<ROW, COL>::default();
    let keymap = initialize_keymap(&mut keymap_data, &mut behavior, &positional).await;

    // ---- Onboard profile storage ---------------------------------------
    let mut flash = Flash::<_, Blocking, FLASH_SIZE>::new_blocking(p.FLASH);
    protocol::load_mapping(&mut flash);

    // ---- Matrix (col2row: drive GP1..4, read GP5..8) --------------------
    let row_pins = [
        Input::new(p.PIN_5, Pull::Down),
        Input::new(p.PIN_6, Pull::Down),
        Input::new(p.PIN_7, Pull::Down),
        Input::new(p.PIN_8, Pull::Down),
    ];
    let col_pins = [
        Output::new(p.PIN_1, Level::Low),
        Output::new(p.PIN_2, Level::Low),
        Output::new(p.PIN_3, Level::Low),
        Output::new(p.PIN_4, Level::Low),
    ];
    let mut matrix =
        Matrix::<_, _, _, 4, 4, true>::new(row_pins, col_pins, DefaultDebouncer::new());

    // ---- Encoders (GP16/17, GP19/20, GP22/26) ---------------------------
    let mut encoders = Encoders::new([
        (
            Input::new(p.PIN_16, Pull::Up),
            Input::new(p.PIN_17, Pull::Up),
        ),
        (
            Input::new(p.PIN_19, Pull::Up),
            Input::new(p.PIN_20, Pull::Up),
        ),
        (
            Input::new(p.PIN_22, Pull::Up),
            Input::new(p.PIN_26, Pull::Up),
        ),
    ]);

    // ---- Encoder push-buttons (GP18, GP21, GP27) ------------------------
    let mut buttons = EncoderButtons::new([
        Input::new(p.PIN_18, Pull::Up),
        Input::new(p.PIN_21, Pull::Up),
        Input::new(p.PIN_27, Pull::Up),
    ]);

    // ---- OLED (SSD1306 128x32 on I2C1, SDA GP10, SCL GP11) --------------
    let i2c = I2c::new_async(p.I2C1, p.PIN_11, p.PIN_10, Irqs, i2c::Config::default());
    let display_interface = I2CDisplayInterface::new_custom_address(i2c, OLED_ADDRESS);
    let display = Ssd1306Async::new(
        display_interface,
        DisplaySize128x32,
        DisplayRotation::Rotate180,
    )
    .into_buffered_graphics_mode();
    let mut display_processor = OledDisplay::new(display);

    // ---- USB: keyboard HID (RMK) + NovaKey raw HID ----------------------
    let driver = Driver::new(p.USB, Irqs);
    let device_config = DeviceConfig {
        vid: 0xFEED,
        pid: 0x4E4B,
        manufacturer: "NovaKey",
        product_name: "NovaKey Macropad",
        serial_number: "novakey:2",
    };
    static NOVAKEY_HID_STATE: static_cell::StaticCell<embassy_usb::class::hid::State<'static>> =
        static_cell::StaticCell::new();
    let mut usb_builder = UsbTransport::builder(driver, device_config);
    let hid_config = embassy_usb::class::hid::Config {
        report_descriptor: protocol::REPORT_DESCRIPTOR,
        request_handler: None,
        poll_ms: 1,
        max_packet_size: 32,
        hid_subclass: embassy_usb::class::hid::HidSubclass::No,
        hid_boot_protocol: embassy_usb::class::hid::HidBootProtocol::None,
    };
    let novakey_rw = embassy_usb::class::hid::HidReaderWriter::<_, 32, 32>::new(
        usb_builder.usb_builder(),
        NOVAKEY_HID_STATE.init(embassy_usb::class::hid::State::new()),
        hid_config,
    );
    let mut usb_transport = usb_builder.build();
    let (novakey_reader, novakey_writer) = novakey_rw.split();

    // ---- Core + custom processors --------------------------------------
    let mut keyboard = Keyboard::new(&keymap);
    let mut control_processor = ControlProcessor::new();
    let mut emitter = Emitter::new();

    let mut watchdog_runner = Rp2040Watchdog::default_runner(Watchdog::new(p.WATCHDOG));

    // ---- Run everything --------------------------------------------------
    join(
        join(
            join3(usb_transport.run(), matrix.run(), encoders.run()),
            join5(
                buttons.run(),
                control_processor.run(),
                emitter.run(),
                display_processor.run(),
                keyboard.run(),
            ),
        ),
        join3(
            watchdog_runner.run(),
            protocol::run_reader(novakey_reader, flash),
            protocol::run_writer(novakey_writer),
        ),
    )
    .await;
}
