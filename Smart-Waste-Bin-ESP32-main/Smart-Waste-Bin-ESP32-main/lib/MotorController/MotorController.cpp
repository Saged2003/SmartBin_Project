#include "MotorController.h"
#include "../../include/Config.h"

AccelStepper stepper(1, STEP_PIN, DIR_PIN);

void MotorController::init() {
  pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);

  stepper.setMaxSpeed(1000.0);
  stepper.setAcceleration(500.0);
  stepper.setCurrentPosition(0);
}

bool MotorController::tiltToPlastic() {
  Serial.println("Tilting to Plastic Section...");
  stepper.moveTo(STEPS_TO_PLASTIC);
  return runToPosition();
}

bool MotorController::tiltToMetal() {
  Serial.println("Tilting to Metal Section...");
  stepper.moveTo(STEPS_TO_METAL);
  return runToPosition();
}

bool MotorController::resetToCenter() {
  Serial.println("Returning to Center...");
  stepper.moveTo(STEPS_CENTER);
  return runToPosition();
}

bool MotorController::runToPosition() {
  digitalWrite(ENABLE_PIN, LOW);
  delay(10);

  while (stepper.distanceToGo() != 0) {
    if (digitalRead(BUTTON_PIN) == LOW) {
      Serial.println("Button Pressed! Interrupting and Ending Session...");
      stepper.moveTo(STEPS_CENTER);

      while (stepper.distanceToGo() != 0) {
        stepper.run();
        yield();
      }

      digitalWrite(ENABLE_PIN, HIGH);
      return false;
    }

    stepper.run();
    yield();
  }

  digitalWrite(ENABLE_PIN, HIGH);
  return true;
}