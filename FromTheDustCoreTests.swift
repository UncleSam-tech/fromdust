import Foundation
import FromTheDustCore

@main
struct FromTheDustCoreChecks {
    static func main() throws {
        try clockAdvancesAcrossLeapDayDeterministically()
        try clockCannotMoveBackwards()
        try invalidCalendarDateIsRejected()
        try ageChangesOnExactBirthday()
        try leapDayBirthUsesTheExactAnniversary()
        try lifeStageIsDerivedRatherThanStored()
        try personRoundTripsThroughJSON()
        try newLifeDerivesAgeFromExactDateOfBirth()
        try newLifeRejectsAStartBeforeBirth()
        try newLifeRoundTripsWithoutStoredAge()
        try decodedNewLifeRejectsAClockBeforeBirth()

        print("PASS: FromTheDustCore checks")
    }

    private static func clockAdvancesAcrossLeapDayDeterministically() throws {
        let start = try SimulationDate(year: 2028, month: 2, day: 28)
        var clock = SimulationClock(startingOn: start)

        let leapDay = try clock.advance()
        let marchFirst = try clock.advance()
        let expectedLeapDay = try SimulationDate(year: 2028, month: 2, day: 29)
        let expectedMarchFirst = try SimulationDate(year: 2028, month: 3, day: 1)

        precondition(leapDay == expectedLeapDay)
        precondition(marchFirst == expectedMarchFirst)
        precondition(clock.elapsedDays == 2)
    }

    private static func clockCannotMoveBackwards() throws {
        let start = try SimulationDate(year: 2026, month: 7, day: 30)
        let earlier = try SimulationDate(year: 2026, month: 7, day: 29)
        var clock = SimulationClock(startingOn: start)

        do {
            try clock.advance(to: earlier)
            preconditionFailure("The simulation clock moved backwards")
        } catch SimulationTimeError.cannotReverse(from: start, to: earlier) {
        }
    }

    private static func invalidCalendarDateIsRejected() throws {
        do {
            _ = try SimulationDate(year: 2026, month: 2, day: 29)
            preconditionFailure("An invalid calendar date was accepted")
        } catch SimulationTimeError.invalidDate(year: 2026, month: 2, day: 29) {
        }
    }

    private static func ageChangesOnExactBirthday() throws {
        let person = try makePerson(born: (2012, 8, 14))

        let dayBefore = try SimulationDate(year: 2026, month: 8, day: 13)
        let birthday = try SimulationDate(year: 2026, month: 8, day: 14)
        let ageBefore = try person.age(on: dayBefore)
        let ageOnBirthday = try person.age(on: birthday)

        precondition(ageBefore == 13)
        precondition(ageOnBirthday == 14)
    }

    private static func leapDayBirthUsesTheExactAnniversary() throws {
        let person = try makePerson(born: (2000, 2, 29))

        let februaryLast = try SimulationDate(year: 2026, month: 2, day: 28)
        let marchFirst = try SimulationDate(year: 2026, month: 3, day: 1)
        let ageBeforeAnniversary = try person.age(on: februaryLast)
        let ageAfterAnniversary = try person.age(on: marchFirst)

        precondition(ageBeforeAnniversary == 25)
        precondition(ageAfterAnniversary == 26)
    }

    private static func lifeStageIsDerivedRatherThanStored() throws {
        let person = try makePerson(born: (2008, 7, 30))

        let dayBefore = try SimulationDate(year: 2026, month: 7, day: 29)
        let birthday = try SimulationDate(year: 2026, month: 7, day: 30)
        let stageBefore = try person.lifeStage(on: dayBefore)
        let stageOnBirthday = try person.lifeStage(on: birthday)

        precondition(stageBefore == .adolescence)
        precondition(stageOnBirthday == .adulthood)
    }

    private static func personRoundTripsThroughJSON() throws {
        let person = try makePerson(born: (2001, 12, 3))
        let data = try JSONEncoder().encode(person)
        let restored = try JSONDecoder().decode(Person.self, from: data)

        precondition(restored == person)
    }

    private static func newLifeDerivesAgeFromExactDateOfBirth() throws {
        let draft = try makeDraft(
            born: (2010, 8, 3),
            starting: (2026, 8, 2)
        )
        var life = try draft.create()

        let expectedBirthDate = try SimulationDate(year: 2010, month: 8, day: 3)

        precondition(life.protagonist.dateOfBirth == expectedBirthDate)
        precondition(life.age == 15)

        try life.advance()
        precondition(life.age == 16)
    }

    private static func newLifeRejectsAStartBeforeBirth() throws {
        let draft = try makeDraft(
            born: (2026, 8, 3),
            starting: (2026, 8, 2)
        )
        let expectedStart = try SimulationDate(year: 2026, month: 8, day: 2)
        let expectedBirth = try SimulationDate(year: 2026, month: 8, day: 3)

        do {
            _ = try draft.create()
            preconditionFailure("A playable life started before birth")
        } catch NewLifeError.startsBeforeBirth(start: expectedStart, birth: expectedBirth) {
        }
    }

    private static func newLifeRoundTripsWithoutStoredAge() throws {
        let original = try makeDraft(
            born: (2000, 2, 29),
            starting: (2026, 2, 28)
        ).create()
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NewLife.self, from: data)

        precondition(restored == original)
        precondition(restored.age == 25)
        precondition(restored.clock.elapsedDays == 0)
    }

    private static func decodedNewLifeRejectsAClockBeforeBirth() throws {
        let invalidSave = """
        {
          "protagonist": {
            "id": "player-001",
            "name": { "given": "Ada", "family": "Okafor" },
            "dateOfBirth": { "year": 2026, "month": 8, "day": 3 }
          },
          "clock": {
            "currentDate": { "year": 2026, "month": 8, "day": 2 },
            "elapsedDays": 0
          }
        }
        """

        do {
            _ = try JSONDecoder().decode(NewLife.self, from: Data(invalidSave.utf8))
            preconditionFailure("An invalid playable-life save was decoded")
        } catch DecodingError.dataCorrupted {
        }
    }

    private static func makePerson(born birth: (Int, Int, Int)) throws -> Person {
        Person(
            id: PersonID(rawValue: "person-001")!,
            name: try PersonName(given: "Ada", family: "Okafor"),
            dateOfBirth: try SimulationDate(
                year: birth.0,
                month: birth.1,
                day: birth.2
            )
        )
    }

    private static func makeDraft(
        born birth: (Int, Int, Int),
        starting start: (Int, Int, Int)
    ) throws -> NewLifeDraft {
        NewLifeDraft(
            personID: PersonID(rawValue: "player-001")!,
            name: try PersonName(given: "Ada", family: "Okafor"),
            dateOfBirth: try SimulationDate(
                year: birth.0,
                month: birth.1,
                day: birth.2
            ),
            startingDate: try SimulationDate(
                year: start.0,
                month: start.1,
                day: start.2
            )
        )
    }
}
