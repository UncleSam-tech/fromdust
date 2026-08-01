import Testing
@testable import FromTheDustCore

@Suite("From the Dust core")
struct FromTheDustCoreTests {
    @Test
    func clockAdvancesAcrossLeapDayDeterministically() throws {
        let start = try SimulationDate(year: 2028, month: 2, day: 28)
        var clock = SimulationClock(startingOn: start)

        #expect(try clock.advance() == SimulationDate(year: 2028, month: 2, day: 29))
        #expect(try clock.advance() == SimulationDate(year: 2028, month: 3, day: 1))
        #expect(clock.elapsedDays == 2)
    }

    @Test
    func clockCannotMoveBackwards() throws {
        let start = try SimulationDate(year: 2026, month: 7, day: 30)
        let earlier = try SimulationDate(year: 2026, month: 7, day: 29)
        var clock = SimulationClock(startingOn: start)

        #expect(throws: SimulationTimeError.cannotReverse(from: start, to: earlier)) {
            try clock.advance(to: earlier)
        }
    }

    @Test
    func invalidCalendarDateIsRejected() {
        #expect(throws: SimulationTimeError.invalidDate(year: 2026, month: 2, day: 29)) {
            try SimulationDate(year: 2026, month: 2, day: 29)
        }
    }

    @Test
    func ageChangesOnExactBirthday() throws {
        let person = try makePerson(born: (2012, 8, 14))

        #expect(try person.age(on: SimulationDate(year: 2026, month: 8, day: 13)) == 13)
        #expect(try person.age(on: SimulationDate(year: 2026, month: 8, day: 14)) == 14)
    }

    @Test
    func lifeStageIsDerivedRatherThanStored() throws {
        let person = try makePerson(born: (2008, 7, 30))

        #expect(
            try person.lifeStage(on: SimulationDate(year: 2026, month: 7, day: 29))
                == .adolescence
        )
        #expect(
            try person.lifeStage(on: SimulationDate(year: 2026, month: 7, day: 30))
                == .adulthood
        )
    }

    @Test
    func personRoundTripsThroughJSON() throws {
        let person = try makePerson(born: (2001, 12, 3))
        let data = try JSONEncoder().encode(person)

        #expect(try JSONDecoder().decode(Person.self, from: data) == person)
    }

    private func makePerson(born birth: (Int, Int, Int)) throws -> Person {
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
}
