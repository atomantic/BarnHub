import XCTest
import SwiftUI
@testable import BarnHub

final class AppearanceManagerTests: XCTestCase {

    private let defaultsKey = "net.shadowpuppet.BarnBook.appearanceMode"

    override func setUp() {
        super.setUp()
        // Reset the UserDefaults key before each test for isolation
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    // MARK: - AppearanceMode.colorScheme mapping

    func test_appearanceMode_system_mapsToNilColorScheme() {
        XCTAssertNil(AppearanceMode.system.colorScheme)
    }

    func test_appearanceMode_light_mapsToLightColorScheme() {
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light)
    }

    func test_appearanceMode_dark_mapsToDarkColorScheme() {
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }

    // MARK: - AppearanceMode.displayName

    func test_appearanceMode_system_displayName() {
        XCTAssertEqual(AppearanceMode.system.displayName, "System")
    }

    func test_appearanceMode_light_displayName() {
        XCTAssertEqual(AppearanceMode.light.displayName, "Light")
    }

    func test_appearanceMode_dark_displayName() {
        XCTAssertEqual(AppearanceMode.dark.displayName, "Dark")
    }

    // MARK: - AppearanceMode rawValues

    func test_appearanceMode_rawValues_areStable() {
        XCTAssertEqual(AppearanceMode.system.rawValue, 0)
        XCTAssertEqual(AppearanceMode.light.rawValue, 1)
        XCTAssertEqual(AppearanceMode.dark.rawValue, 2)
    }

    // MARK: - AppearanceManager persistence

    func test_appearanceManager_defaultMode_isSystem() {
        let manager = AppearanceManager()
        XCTAssertEqual(manager.mode, .system)
    }

    func test_appearanceManager_setMode_persistsToUserDefaults() {
        let manager = AppearanceManager()
        manager.mode = .dark
        XCTAssertEqual(UserDefaults.standard.integer(forKey: defaultsKey), AppearanceMode.dark.rawValue)
    }

    func test_appearanceManager_loadsPersistedMode() {
        // Pre-set defaults to simulate a previous launch that chose .light
        UserDefaults.standard.set(AppearanceMode.light.rawValue, forKey: defaultsKey)

        let manager = AppearanceManager()
        XCTAssertEqual(manager.mode, .light)
    }

    func test_appearanceManager_loadsPersistedDarkMode() {
        UserDefaults.standard.set(AppearanceMode.dark.rawValue, forKey: defaultsKey)
        let manager = AppearanceManager()
        XCTAssertEqual(manager.mode, .dark)
    }

    func test_appearanceManager_invalidStoredValue_defaultsToSystem() {
        // Store an out-of-range value
        UserDefaults.standard.set(99, forKey: defaultsKey)
        let manager = AppearanceManager()
        XCTAssertEqual(manager.mode, .system)
    }

    // MARK: - colorScheme computed property

    func test_appearanceManager_colorScheme_systemMode_isNil() {
        let manager = AppearanceManager()
        manager.mode = .system
        XCTAssertNil(manager.colorScheme)
    }

    func test_appearanceManager_colorScheme_lightMode_isLight() {
        let manager = AppearanceManager()
        manager.mode = .light
        XCTAssertEqual(manager.colorScheme, .light)
    }

    func test_appearanceManager_colorScheme_darkMode_isDark() {
        let manager = AppearanceManager()
        manager.mode = .dark
        XCTAssertEqual(manager.colorScheme, .dark)
    }
}
