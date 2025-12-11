//! Magic Trackpad Dead Zone Filter

use evdev::{
    uinput::VirtualDeviceBuilder,
    AbsoluteAxisType, AbsInfo, Device, EventType, InputEvent, InputEventKind, UinputAbsSetup,
};
use std::collections::HashMap;
use std::thread::sleep;
use std::time::Duration;

// Dead zone config (fractions of trackpad dimensions)
const DEADZONE_X_LEFT: f64 = 0.20;
const DEADZONE_X_RIGHT: f64 = 0.80;
const DEADZONE_Y_TOP: f64 = 0.50;

const VENDOR_APPLE: u16 = 0x004C;
const PRODUCT_MAGIC_TRACKPAD: u16 = 0x0265;

/// Check if coordinates fall within a dead zone.
/// Dead zones are: left 20% AND top 50%, OR right 20% AND top 50%
fn in_deadzone(x: i32, y: i32, max_x: i32, max_y: i32) -> bool {
    if x < 0 || y < 0 || max_x <= 0 || max_y <= 0 {
        return false;
    }
    let x_frac = x as f64 / max_x as f64;
    let y_frac = y as f64 / max_y as f64;
    let in_left = x_frac < DEADZONE_X_LEFT;
    let in_right = x_frac > DEADZONE_X_RIGHT;
    let in_top = y_frac < DEADZONE_Y_TOP;
    (in_left || in_right) && in_top
}

#[derive(Default)]
struct SlotState {
    first_x: Option<i32>,
    first_y: Option<i32>,
    blocked: bool,
}

fn find_magic_trackpad() -> Option<Device> {
    evdev::enumerate()
        .map(|(_, d)| d)
        .find(|d| {
            let id = d.input_id();
            id.vendor() == VENDOR_APPLE && id.product() == PRODUCT_MAGIC_TRACKPAD
        })
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    eprintln!("magictouch-deadzone starting...");

    let mut device = loop {
        if let Some(d) = find_magic_trackpad() {
            break d;
        }
        eprintln!("Waiting for Magic Trackpad...");
        sleep(Duration::from_secs(2));
    };

    eprintln!("Found: {}", device.name().unwrap_or("unknown"));

    // Get trackpad dimensions
    let abs_state = device.get_abs_state()?;
    let max_x = abs_state.get(AbsoluteAxisType::ABS_MT_POSITION_X.0 as usize)
        .map(|a| a.maximum).unwrap_or(1);
    let max_y = abs_state.get(AbsoluteAxisType::ABS_MT_POSITION_Y.0 as usize)
        .map(|a| a.maximum).unwrap_or(1);
    eprintln!("Range: X=0-{}, Y=0-{}", max_x, max_y);

    // Create virtual device with same capabilities
    let virt_name = format!("{} (filtered)", device.name().unwrap_or("trackpad"));
    let mut builder = VirtualDeviceBuilder::new()?.name(&virt_name);

    // Copy device properties (INPUT_PROP_POINTER, INPUT_PROP_BUTTONPAD, etc.)
    builder = builder.with_properties(device.properties())?;

    // Copy supported keys
    if let Some(keys) = device.supported_keys() {
        builder = builder.with_keys(&keys)?;
    }

    // Copy absolute axes with their configuration
    if let Some(abs_axes) = device.supported_absolute_axes() {
        for axis in abs_axes.iter() {
            if let Some(info) = device.get_abs_state()?.get(axis.0 as usize) {
                let setup = UinputAbsSetup::new(axis,
                    AbsInfo::new(info.value, info.minimum, info.maximum, info.fuzz, info.flat, info.resolution));
                builder = builder.with_absolute_axis(&setup)?;
            }
        }
    }

    let mut virt = builder.build()?;
    device.grab()?;
    eprintln!("Filtering active.");

    let mut slots: HashMap<i32, SlotState> = HashMap::new();
    let mut current_slot: i32 = 0;

    loop {
        for event in device.fetch_events()? {
            let mut suppress = false;

            if event.event_type() == EventType::ABSOLUTE {
                match event.kind() {
                    InputEventKind::AbsAxis(AbsoluteAxisType::ABS_MT_SLOT) => {
                        current_slot = event.value();
                    }
                    InputEventKind::AbsAxis(AbsoluteAxisType::ABS_MT_TRACKING_ID) => {
                        if event.value() == -1 {
                            if slots.get(&current_slot).map(|s| s.blocked).unwrap_or(false) {
                                suppress = true;
                            }
                            slots.remove(&current_slot);
                        } else {
                            slots.insert(current_slot, SlotState::default());
                        }
                    }
                    InputEventKind::AbsAxis(AbsoluteAxisType::ABS_MT_POSITION_X) => {
                        if let Some(slot) = slots.get_mut(&current_slot) {
                            if slot.first_x.is_none() {
                                slot.first_x = Some(event.value());
                                if let Some(y) = slot.first_y {
                                    if in_deadzone(event.value(), y, max_x, max_y) {
                                        slot.blocked = true;
                                        eprintln!("Blocked slot {} at ({}, {})", current_slot, event.value(), y);
                                        let cancel = InputEvent::new(EventType::ABSOLUTE, AbsoluteAxisType::ABS_MT_TRACKING_ID.0, -1);
                                        virt.emit(&[cancel])?;
                                    }
                                }
                            }
                            if slot.blocked { suppress = true; }
                        }
                    }
                    InputEventKind::AbsAxis(AbsoluteAxisType::ABS_MT_POSITION_Y) => {
                        if let Some(slot) = slots.get_mut(&current_slot) {
                            if slot.first_y.is_none() {
                                slot.first_y = Some(event.value());
                                if let Some(x) = slot.first_x {
                                    if in_deadzone(x, event.value(), max_x, max_y) {
                                        slot.blocked = true;
                                        eprintln!("Blocked slot {} at ({}, {})", current_slot, x, event.value());
                                        let cancel = InputEvent::new(EventType::ABSOLUTE, AbsoluteAxisType::ABS_MT_TRACKING_ID.0, -1);
                                        virt.emit(&[cancel])?;
                                    }
                                }
                            }
                            if slot.blocked { suppress = true; }
                        }
                    }
                    InputEventKind::AbsAxis(
                        AbsoluteAxisType::ABS_MT_TOUCH_MAJOR
                        | AbsoluteAxisType::ABS_MT_TOUCH_MINOR
                        | AbsoluteAxisType::ABS_MT_PRESSURE
                        | AbsoluteAxisType::ABS_MT_ORIENTATION
                    ) => {
                        if slots.get(&current_slot).map(|s| s.blocked).unwrap_or(false) {
                            suppress = true;
                        }
                    }
                    _ => {}
                }
            }

            if !suppress {
                virt.emit(&[event])?;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Trackpad dimensions from real device
    const MAX_X: i32 = 3934;
    const MAX_Y: i32 = 2587;

    #[test]
    fn test_center_not_blocked() {
        // Center of trackpad (50%, 50%)
        let x = MAX_X / 2;
        let y = MAX_Y / 2;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Center should not be blocked");
    }

    #[test]
    fn test_top_center_not_blocked() {
        // Top center (50%, 25%) - top half but not in corners
        let x = MAX_X / 2;
        let y = MAX_Y / 4;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Top center should not be blocked");
    }

    #[test]
    fn test_bottom_left_not_blocked() {
        // Bottom left (10%, 75%) - left side but bottom half
        let x = MAX_X / 10;
        let y = (MAX_Y * 3) / 4;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Bottom left should not be blocked");
    }

    #[test]
    fn test_bottom_right_not_blocked() {
        // Bottom right (90%, 75%) - right side but bottom half
        let x = (MAX_X * 9) / 10;
        let y = (MAX_Y * 3) / 4;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Bottom right should not be blocked");
    }

    #[test]
    fn test_top_left_corner_blocked() {
        // Top left corner (10%, 25%) - left 20% AND top 50%
        let x = MAX_X / 10;  // 10% from left
        let y = MAX_Y / 4;   // 25% from top
        assert!(in_deadzone(x, y, MAX_X, MAX_Y), "Top left corner should be blocked");
    }

    #[test]
    fn test_top_right_corner_blocked() {
        // Top right corner (90%, 25%) - right 20% AND top 50%
        let x = (MAX_X * 9) / 10;  // 90% from left = right 10%
        let y = MAX_Y / 4;          // 25% from top
        assert!(in_deadzone(x, y, MAX_X, MAX_Y), "Top right corner should be blocked");
    }

    #[test]
    fn test_edge_of_left_deadzone() {
        // Just inside left deadzone (19%, 25%)
        let x = (MAX_X * 19) / 100;
        let y = MAX_Y / 4;
        assert!(in_deadzone(x, y, MAX_X, MAX_Y), "Just inside left deadzone should be blocked");

        // Just outside left deadzone (21%, 25%)
        let x = (MAX_X * 21) / 100;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Just outside left deadzone should not be blocked");
    }

    #[test]
    fn test_edge_of_right_deadzone() {
        // Just inside right deadzone (81%, 25%)
        let x = (MAX_X * 81) / 100;
        let y = MAX_Y / 4;
        assert!(in_deadzone(x, y, MAX_X, MAX_Y), "Just inside right deadzone should be blocked");

        // Just outside right deadzone (79%, 25%)
        let x = (MAX_X * 79) / 100;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Just outside right deadzone should not be blocked");
    }

    #[test]
    fn test_edge_of_top_deadzone() {
        // Just inside top deadzone (10%, 49%)
        let x = MAX_X / 10;
        let y = (MAX_Y * 49) / 100;
        assert!(in_deadzone(x, y, MAX_X, MAX_Y), "Just inside top deadzone should be blocked");

        // Just outside top deadzone (10%, 51%)
        let y = (MAX_Y * 51) / 100;
        assert!(!in_deadzone(x, y, MAX_X, MAX_Y), "Just outside top deadzone should not be blocked");
    }

    #[test]
    fn test_negative_coords_not_blocked() {
        assert!(!in_deadzone(-100, 100, MAX_X, MAX_Y), "Negative X should not be blocked");
        assert!(!in_deadzone(100, -100, MAX_X, MAX_Y), "Negative Y should not be blocked");
        assert!(!in_deadzone(-100, -100, MAX_X, MAX_Y), "Negative X and Y should not be blocked");
    }

    #[test]
    fn test_zero_max_not_blocked() {
        assert!(!in_deadzone(100, 100, 0, MAX_Y), "Zero max_x should not be blocked");
        assert!(!in_deadzone(100, 100, MAX_X, 0), "Zero max_y should not be blocked");
    }
}
