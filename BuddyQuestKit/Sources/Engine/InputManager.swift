import Foundation
import SpriteKit
import GameController

// MARK: - Input Actions

public enum InputAction: String, CaseIterable {
    case moveUp, moveDown, moveLeft, moveRight
    case interact   // E / tap target
    case cancel     // Escape / back swipe
    case pause      // P / menu button
    case inventory  // I / inventory button
    case confirm    // Enter / tap
    case questLog   // Q / quest journal
}

// MARK: - Input State

public struct InputState {
    public var movement: CGPoint = .zero  // Normalized direction vector
    public var justPressed: Set<InputAction> = []
    public var held: Set<InputAction> = []
    public var justReleased: Set<InputAction> = []

    /// Characters typed this frame (for text input mode, e.g. fill-in-blank).
    /// Includes printable characters; backspace is represented as "\u{08}".
    public var typedCharacters: [Character] = []

    public func isPressed(_ action: InputAction) -> Bool {
        justPressed.contains(action)
    }

    public func isHeld(_ action: InputAction) -> Bool {
        held.contains(action)
    }

    public func isReleased(_ action: InputAction) -> Bool {
        justReleased.contains(action)
    }
}

// MARK: - Input Manager

public final class InputManager {
    public private(set) var state = InputState()

    /// When true, keyboard character input is buffered into `typedCharacters`
    /// instead of being consumed as game actions. Set by FillInBlankChallenge.
    public var isTextInputActive: Bool = false

    // Keyboard tracking
    private var keysDown: Set<UInt16> = []
    private var keysPressed: Set<UInt16> = []
    private var keysReleased: Set<UInt16> = []

    // Text input buffer (characters typed this frame)
    private var textInputBuffer: [Character] = []

    // Virtual joystick (iOS)
    private var virtualJoystickDirection: CGPoint = .zero
    private var virtualButtonsPressed: Set<InputAction> = []

    // Key code mapping (macOS)
    private static let keyMap: [UInt16: InputAction] = [
        0x0D: .moveUp,     // W
        0x01: .moveDown,   // S
        0x00: .moveLeft,   // A
        0x02: .moveRight,  // D
        0x7E: .moveUp,     // Arrow Up
        0x7D: .moveDown,   // Arrow Down
        0x7B: .moveLeft,   // Arrow Left
        0x7C: .moveRight,  // Arrow Right
        0x0E: .interact,   // E
        0x24: .confirm,    // Return
        0x35: .cancel,     // Escape
        0x23: .pause,      // P
        0x22: .inventory,  // I
        0x0C: .questLog,   // Q
        0x31: .confirm,    // Space
    ]

    public init() {
        setupGameControllerObservers()
    }

    // MARK: - Frame Update

    /// Call at the start of each frame to compute the current input state
    public func update() {
        var newState = InputState()

        // Compute movement from keyboard
        var moveX: CGFloat = 0
        var moveY: CGFloat = 0

        if isKeyDown(.moveUp) { moveY += 1 }
        if isKeyDown(.moveDown) { moveY -= 1 }
        if isKeyDown(.moveLeft) { moveX -= 1 }
        if isKeyDown(.moveRight) { moveX += 1 }

        var movement = CGPoint(x: moveX, y: moveY)

        // Blend in virtual joystick
        if virtualJoystickDirection.length > 0.1 {
            movement = virtualJoystickDirection
        }

        // Normalize diagonal movement
        if movement.length > 1 {
            movement = movement.normalized()
        }

        newState.movement = movement

        // Compute button states
        // When text input is active, suppress letter-key game actions (WASD, E, P, I, Q)
        // so they only feed the text buffer. Arrow keys, Return, Escape still work.
        let suppressedKeyCodes: Set<UInt16> = isTextInputActive
            ? [0x0D, 0x01, 0x00, 0x02, 0x0E, 0x23, 0x22, 0x0C, 0x31]  // W, S, A, D, E, P, I, Q, Space
            : []
        for (keyCode, action) in Self.keyMap {
            if suppressedKeyCodes.contains(keyCode) { continue }
            if keysPressed.contains(keyCode) {
                newState.justPressed.insert(action)
            }
            if keysDown.contains(keyCode) {
                newState.held.insert(action)
            }
            if keysReleased.contains(keyCode) {
                newState.justReleased.insert(action)
            }
        }

        // Merge virtual button presses
        for action in virtualButtonsPressed {
            newState.justPressed.insert(action)
        }

        // Transfer text input buffer
        newState.typedCharacters = textInputBuffer

        state = newState

        // Clear per-frame events
        keysPressed.removeAll()
        keysReleased.removeAll()
        virtualButtonsPressed.removeAll()
        textInputBuffer.removeAll()
    }

    // MARK: - Keyboard Input (macOS / hardware keyboard on iPad)

    public func keyDown(keyCode: UInt16) {
        if !keysDown.contains(keyCode) {
            keysPressed.insert(keyCode)
        }
        keysDown.insert(keyCode)
    }

    /// Extended keyDown that also captures typed characters for text input mode.
    /// Call this instead of `keyDown(keyCode:)` when `NSEvent.characters` is available.
    public func keyDown(keyCode: UInt16, characters: String?) {
        keyDown(keyCode: keyCode)

        // Buffer characters for text input when active
        if isTextInputActive, let chars = characters {
            for char in chars {
                // Filter: allow letters, digits, space, punctuation useful for answers
                if char.isLetter || char.isNumber || char == " " || char == "." || char == "-" || char == "," || char == "'" {
                    textInputBuffer.append(char)
                }
            }
            // Handle backspace (keyCode 0x33)
            if keyCode == 0x33 {
                textInputBuffer.append(Character("\u{08}"))  // backspace marker
            }
        }
    }

    public func keyUp(keyCode: UInt16) {
        keysDown.remove(keyCode)
        keysReleased.insert(keyCode)
    }

    // MARK: - Virtual Joystick (iOS)

    public func setVirtualJoystick(direction: CGPoint) {
        virtualJoystickDirection = direction
    }

    public func pressVirtualButton(_ action: InputAction) {
        virtualButtonsPressed.insert(action)
    }

    // MARK: - Helpers

    private func isKeyDown(_ action: InputAction) -> Bool {
        for (keyCode, mappedAction) in Self.keyMap {
            if mappedAction == action && keysDown.contains(keyCode) {
                return true
            }
        }
        return false
    }

    // MARK: - Game Controller Support

    private func setupGameControllerObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.configureController(controller)
        }

        // Configure any already-connected controllers
        for controller in GCController.controllers() {
            configureController(controller)
        }
    }

    private func configureController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.virtualJoystickDirection = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue))
        }

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.virtualJoystickDirection = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue))
        }

        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.virtualButtonsPressed.insert(.interact) }
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.virtualButtonsPressed.insert(.cancel) }
        }

        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.virtualButtonsPressed.insert(.pause) }
        }
    }
}
