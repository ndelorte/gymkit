import XCTest

/// End-to-end coverage of the goal's Core Acceptance Scenario: create a
/// template, run a session, finish it, relaunch the app, confirm previous
/// values are preloaded (but not pre-completed), run a second session,
/// terminate mid-workout and confirm the active session resumes, finish it,
/// and confirm the PR shows up in the exercise detail screen.
final class AppGymUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreAcceptanceScenario() throws {
        let app = XCUIApplication()
        // Pin the locale so weight formatting ("82.5" vs "82,5") is
        // deterministic regardless of the host simulator's region settings.
        app.launchArguments = ["-UITestReset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        createPushATemplate(app)
        startTemplate(app, named: "Push A")
        performSets(app, exercise: "Press banca", values: [(80, 8), (80, 8), (80, 7)])
        finishWorkout(app)

        // Relaunch without the reset flag: the finished session must survive.
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        goToTab(app, "Historial")
        XCTAssertTrue(app.staticTexts["Push A"].waitForExistence(timeout: 5), "La sesión finalizada debería aparecer en el historial")

        goToTab(app, "Entrenar")
        startTemplate(app, named: "Push A")

        // Previous values must be preloaded but NOT marked as completed.
        let weight0 = app.textFields["Press banca_0_weight"]
        XCTAssertTrue(weight0.waitForExistence(timeout: 5))
        XCTAssertEqual(weight0.value as? String, "80")
        XCTAssertEqual(app.textFields["Press banca_0_reps"].value as? String, "8")
        XCTAssertEqual(app.buttons["Press banca_0_complete"].value as? String, "pendiente")
        XCTAssertTrue(app.staticTexts["Anterior: 80×8"].firstMatch.exists)

        performSets(app, exercise: "Press banca", values: [(82.5, 8), (82.5, 7), (80, 8)])

        // Terminate mid-workout (before finishing) and relaunch: the active
        // session itself — not just finished history — must survive and
        // resume with the same in-progress values.
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let resumedWeight0 = app.textFields["Press banca_0_weight"]
        XCTAssertTrue(resumedWeight0.waitForExistence(timeout: 5), "La sesión activa debería recuperarse automáticamente")
        XCTAssertEqual(resumedWeight0.value as? String, "82.5")
        XCTAssertEqual(app.buttons["Press banca_0_complete"].value as? String, "completado")

        finishWorkout(app)

        goToTab(app, "Ejercicios")
        scrollToElement(app, app.buttons["Press banca"]).tap()
        if !app.staticTexts["82.5 kg"].waitForExistence(timeout: 5) {
            print("=== DEBUG HIERARCHY (82.5 kg not found) ===")
            print(app.debugDescription)
        }
        XCTAssertTrue(app.staticTexts["82.5 kg"].exists, "El peso máximo debería reflejar el nuevo PR")
        let prBadges = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'prBadge_'"))
        XCTAssertGreaterThan(prBadges.count, 0, "Debería marcarse un récord personal")
    }

    // MARK: - Steps

    private func createPushATemplate(_ app: XCUIApplication) {
        app.buttons["newTemplateButton"].tap()
        let nameField = app.textFields["templateNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Push A")
        dismissKeyboard(app)

        app.buttons["addExerciseToTemplateButton"].tap()
        selectExercise(app, named: "Press banca")
        app.buttons["confirmAddExercisesButton"].tap()

        app.buttons["saveTemplateButton"].tap()
    }

    /// The exercise library has ~30 seeded entries; a plain `List` only
    /// materializes on-screen rows, so anything not alphabetically near the
    /// top must be filtered into view via search before it can be tapped.
    private func selectExercise(_ app: XCUIApplication, named name: String) {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(name)
        let row = app.buttons["exercisePickerRow_\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        // The search keyboard would otherwise cover the bottom "Añadir" button.
        dismissKeyboard(app)
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.element.exists else { return }
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        } else {
            app.navigationBars.firstMatch.tap()
        }
    }

    private func startTemplate(_ app: XCUIApplication, named name: String) {
        let button = app.buttons["startTemplate_\(name)"]
        if !button.waitForExistence(timeout: 5) {
            print("=== DEBUG HIERARCHY (startTemplate_\(name) not found) ===")
            print(app.debugDescription)
        }
        XCTAssertTrue(button.exists)
        button.tap()
    }

    private func performSets(
        _ app: XCUIApplication,
        exercise: String,
        values: [(weight: Double, reps: Int)]
    ) {
        for (index, value) in values.enumerated() {
            let prefix = "\(exercise)_\(index)"
            let weightField = app.textFields["\(prefix)_weight"]
            XCTAssertTrue(weightField.waitForExistence(timeout: 5))
            let weightString = value.weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", value.weight)
                : String(format: "%.1f", value.weight)
            setField(weightField, to: weightString)

            let repsField = app.textFields["\(prefix)_reps"]
            setField(repsField, to: String(value.reps))

            app.buttons["\(prefix)_complete"].tap()
        }
        dismissKeyboard(app)
    }

    /// `typeText` on the decimal/number keypad occasionally drops a
    /// keystroke (most often the "." key), so this clears, types, and
    /// verifies the result — retrying a few times if the field doesn't end
    /// up holding exactly what was typed.
    private func setField(_ field: XCUIElement, to text: String) {
        for _ in 0..<3 {
            field.tap()
            if let current = field.value as? String, !current.isEmpty {
                // A plain tap can land the cursor mid-string, so a fixed number
                // of backspaces may not fully clear it. Tap the trailing edge
                // first to reliably place the cursor at the end, then over-delete.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4)
                field.typeText(deleteString)
            }
            field.typeText(text)
            if (field.value as? String) == text { return }
        }
        XCTFail("No se pudo escribir '\(text)' de forma fiable (quedó '\(field.value as? String ?? "nil")')")
    }

    private func finishWorkout(_ app: XCUIApplication) {
        app.buttons["finishWorkoutButton"].tap()
        let confirm = app.buttons["Finalizar"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    private func goToTab(_ app: XCUIApplication, _ name: String) {
        app.tabBars.buttons[name].tap()
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Not a correctness test — a smoke pass over the main screens (with real
    /// data on screen) that also captures screenshots as test attachments,
    /// so Dark/Light Mode and overall layout can be inspected visually
    /// without hand-driving the simulator.
    func testMainScreensVisualSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // This test reuses whatever store is already on disk (unlike the
        // acceptance test, it doesn't reset), so a session left active by a
        // previous failed run must be cleared before Home is reachable.
        if !app.buttons["newTemplateButton"].waitForExistence(timeout: 2) {
            for _ in 0..<8 where !app.buttons["finishWorkoutButton"].exists {
                app.swipeUp()
            }
            if app.buttons["finishWorkoutButton"].exists {
                finishWorkout(app)
            }
        }

        attachScreenshot(app, name: "01-home")

        app.buttons["newTemplateButton"].tap()
        _ = app.textFields["templateNameField"].waitForExistence(timeout: 5)
        attachScreenshot(app, name: "01b-new-template")
        app.buttons["addExerciseToTemplateButton"].tap()
        _ = app.searchFields.firstMatch.waitForExistence(timeout: 5)
        attachScreenshot(app, name: "01c-exercise-picker")
        app.buttons["Cancelar"].firstMatch.tap()
        app.buttons["Cancelar"].firstMatch.tap()

        startTemplate(app, named: "Push A")
        _ = app.textFields["Press banca_0_weight"].waitForExistence(timeout: 5)
        attachScreenshot(app, name: "01d-active-workout")

        // Verify exercise reordering actually renders drag handles with 2+
        // exercises (Section-per-exercise + .onMove is a known SwiftUI edge case).
        app.buttons["Añadir ejercicio"].tap()
        selectExercise(app, named: "Sentadilla")
        app.buttons["confirmAddExercisesButton"].tap()
        _ = app.textFields["Sentadilla_0_weight"].waitForExistence(timeout: 5)
        app.buttons["Reordenar"].tap()
        attachScreenshot(app, name: "01e-reordering")
        app.buttons["Listo"].tap()

        scrollToElement(app, app.buttons["finishWorkoutButton"]).tap()
        app.buttons["Finalizar"].tap()

        goToTab(app, "Historial")
        _ = app.tabBars.buttons["Historial"].waitForExistence(timeout: 5)
        attachScreenshot(app, name: "02-historial")

        goToTab(app, "Ejercicios")
        attachScreenshot(app, name: "03-ejercicios")

        scrollToElement(app, app.buttons["Press banca"]).tap()
        XCTAssertTrue(app.staticTexts["Peso máximo"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "04-exercise-detail")
    }

    /// Lazily-rendered lists (the exercise library has ~30 rows across
    /// several sections) don't materialize every row up front, so an element
    /// further down needs the list scrolled toward it before it exists.
    @discardableResult
    private func scrollToElement(_ app: XCUIApplication, _ element: XCUIElement, maxSwipes: Int = 8) -> XCUIElement {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3), "No se encontró el elemento tras desplazarse")
        return element
    }
}
