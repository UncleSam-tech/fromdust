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
        try householdRequiresOneProtagonistAndAnAdultGuardian()
        try childhoodDecisionRecordsItsHouseholdEffect()
        try childhoodAllowsOnlyOneDecisionPerDate()
        try childhoodDecisionIsRejectedAfterChildhood()
        try childhoodHistoryRoundTripsThroughJSON()
        try grassrootsProgrammeRequiresEnoughScreenedCoaches()
        try grassrootsEnrollmentRequiresHouseholdGuardianConsent()
        try grassrootsEnrollmentRespectsProgrammeAgeRange()
        try grassrootsSessionEnforcesSafeguarding()
        try grassrootsParticipationRoundTripsThroughJSON()

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
          },
          "household": {
            "id": "household-001",
            "members": [
              {
                "person": {
                  "id": "player-001",
                  "name": { "given": "Ada", "family": "Okafor" },
                  "dateOfBirth": { "year": 2026, "month": 8, "day": 3 }
                },
                "role": "protagonist"
              },
              {
                "person": {
                  "id": "guardian-001",
                  "name": { "given": "Nneka", "family": "Okafor" },
                  "dateOfBirth": { "year": 1990, "month": 4, "day": 9 }
                },
                "role": "guardian"
              }
            ],
            "support": { "stability": 50, "connection": 50, "availableResources": 50 }
          },
          "childhoodDecisions": []
        }
        """

        do {
            _ = try JSONDecoder().decode(NewLife.self, from: Data(invalidSave.utf8))
            preconditionFailure("An invalid playable-life save was decoded")
        } catch DecodingError.dataCorrupted {
        }
    }

    private static func householdRequiresOneProtagonistAndAnAdultGuardian() throws {
        let protagonist = try makePerson(born: (2015, 8, 5))
        let start = try SimulationDate(year: 2026, month: 8, day: 5)
        let support = try HouseholdSupport(
            stability: 50,
            connection: 50,
            availableResources: 50
        )
        let draft = HouseholdDraft(
            id: HouseholdID(rawValue: "household-001")!,
            members: [HouseholdMember(person: protagonist, role: .protagonist)],
            startingSupport: support
        )

        do {
            _ = try draft.create(protagonist: protagonist, on: start)
            preconditionFailure("A household without an adult guardian was accepted")
        } catch HouseholdError.missingAdultGuardian {
        }
    }

    private static func childhoodDecisionRecordsItsHouseholdEffect() throws {
        var life = try makeDraft(
            born: (2015, 8, 5),
            starting: (2026, 8, 5)
        ).create()
        let decision = try life.recordChildhoodDecision(
            id: ChildhoodDecisionID(rawValue: "choice-001")!,
            choice: .shareResponsibilities
        )

        precondition(decision.date == life.clock.currentDate)
        precondition(decision.supportBefore.stability == 50)
        precondition(decision.supportAfter.stability == 53)
        precondition(decision.supportAfter.connection == 55)
        precondition(decision.supportAfter.availableResources == 49)
        precondition(life.household.support == decision.supportAfter)
        precondition(life.childhoodDecisions == [decision])
    }

    private static func childhoodAllowsOnlyOneDecisionPerDate() throws {
        var life = try makeDraft(
            born: (2015, 8, 5),
            starting: (2026, 8, 5)
        ).create()
        try life.recordChildhoodDecision(
            id: ChildhoodDecisionID(rawValue: "choice-001")!,
            choice: .keepASteadyRoutine
        )

        do {
            try life.recordChildhoodDecision(
                id: ChildhoodDecisionID(rawValue: "choice-002")!,
                choice: .protectQuietTime
            )
            preconditionFailure("Two childhood decisions were recorded on one date")
        } catch ChildhoodDecisionError.decisionAlreadyRecorded(on: life.clock.currentDate) {
        }
    }

    private static func childhoodDecisionIsRejectedAfterChildhood() throws {
        var life = try makeDraft(
            born: (2010, 8, 5),
            starting: (2026, 8, 5)
        ).create()

        do {
            try life.recordChildhoodDecision(
                id: ChildhoodDecisionID(rawValue: "choice-001")!,
                choice: .joinACommunityActivity
            )
            preconditionFailure("A childhood decision was recorded during adolescence")
        } catch ChildhoodDecisionError.requiresChildhood(currentStage: .adolescence) {
        }
    }

    private static func childhoodHistoryRoundTripsThroughJSON() throws {
        var original = try makeDraft(
            born: (2015, 8, 5),
            starting: (2026, 8, 5)
        ).create()
        try original.recordChildhoodDecision(
            id: ChildhoodDecisionID(rawValue: "choice-001")!,
            choice: .joinACommunityActivity
        )
        try original.advance()
        try original.recordChildhoodDecision(
            id: ChildhoodDecisionID(rawValue: "choice-002")!,
            choice: .protectQuietTime
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NewLife.self, from: data)

        precondition(restored == original)
        precondition(restored.childhoodDecisions.count == 2)
        precondition(restored.household.support.stability == 53)
        precondition(restored.household.support.connection == 55)
        precondition(restored.household.support.availableResources == 48)
    }

    private static func grassrootsProgrammeRequiresEnoughScreenedCoaches() throws {
        let safeguarding = try SafeguardingPolicy(
            maxParticipantsPerScreenedCoach: 10
        )
        let draft = GrassrootsProgrammeDraft(
            id: GrassrootsProgrammeID(rawValue: "programme-001")!,
            name: "Community Football",
            activity: .communityTraining,
            participantCapacity: 24,
            screenedCoachCount: 2,
            safeguarding: safeguarding
        )

        do {
            _ = try draft.create()
            preconditionFailure("An under-supervised programme was accepted")
        } catch GrassrootsError.insufficientScreenedCoaches(
            required: 3,
            available: 2
        ) {
        }
    }

    private static func grassrootsEnrollmentRequiresHouseholdGuardianConsent() throws {
        var life = try makeDraft(
            born: (2015, 8, 6),
            starting: (2026, 8, 6)
        ).create()
        let programme = try makeProgramme()
        let unknownGuardian = PersonID(rawValue: "guardian-not-in-household")!

        do {
            try life.enrollInGrassroots(
                programme: programme,
                consentedBy: unknownGuardian
            )
            preconditionFailure("Enrollment was accepted without guardian consent")
        } catch GrassrootsError.guardianConsentRequired(unknownGuardian) {
        }
    }

    private static func grassrootsEnrollmentRespectsProgrammeAgeRange() throws {
        var life = try makeDraft(
            born: (2008, 8, 6),
            starting: (2026, 8, 6)
        ).create()
        let programme = try makeProgramme()

        do {
            try life.enrollInGrassroots(
                programme: programme,
                consentedBy: PersonID(rawValue: "guardian-001")!
            )
            preconditionFailure("An adult was enrolled in a youth programme")
        } catch GrassrootsError.ageOutsideProgrammeRange(
            age: 18,
            minimum: 8,
            maximum: 15
        ) {
        }
    }

    private static func grassrootsSessionEnforcesSafeguarding() throws {
        var life = try makeDraft(
            born: (2015, 8, 6),
            starting: (2026, 8, 6)
        ).create()
        let programme = try makeProgramme()
        try life.enrollInGrassroots(
            programme: programme,
            consentedBy: PersonID(rawValue: "guardian-001")!
        )

        do {
            try life.recordGrassrootsSession(
                id: GrassrootsSessionID(rawValue: "session-001")!,
                participantCount: 13,
                screenedCoachCount: 2,
                durationMinutes: 75,
                safeguardingLeadPresent: false
            )
            preconditionFailure("A session without its safeguarding lead was accepted")
        } catch GrassrootsError.safeguardingLeadRequired {
        }

        do {
            try life.recordGrassrootsSession(
                id: GrassrootsSessionID(rawValue: "session-002")!,
                participantCount: 13,
                screenedCoachCount: 1,
                durationMinutes: 75,
                safeguardingLeadPresent: true
            )
            preconditionFailure("A session with too few screened coaches was accepted")
        } catch GrassrootsError.insufficientScreenedCoaches(
            required: 2,
            available: 1
        ) {
        }

        do {
            try life.recordGrassrootsSession(
                id: GrassrootsSessionID(rawValue: "session-003")!,
                participantCount: 25,
                screenedCoachCount: 2,
                durationMinutes: 75,
                safeguardingLeadPresent: true
            )
            preconditionFailure("A session exceeded programme capacity")
        } catch GrassrootsError.participantCountOutsideCapacity(25) {
        }

        do {
            try life.recordGrassrootsSession(
                id: GrassrootsSessionID(rawValue: "session-004")!,
                participantCount: 12,
                screenedCoachCount: 1,
                durationMinutes: 20,
                safeguardingLeadPresent: true
            )
            preconditionFailure("An unsafe session duration was accepted")
        } catch GrassrootsError.invalidSessionDuration(20) {
        }

        let session = try life.recordGrassrootsSession(
            id: GrassrootsSessionID(rawValue: "session-005")!,
            participantCount: 13,
            screenedCoachCount: 2,
            durationMinutes: 75,
            safeguardingLeadPresent: true
        )
        precondition(session.date == life.clock.currentDate)
        precondition(life.grassrootsSessions == [session])
    }

    private static func grassrootsParticipationRoundTripsThroughJSON() throws {
        var original = try makeDraft(
            born: (2015, 8, 6),
            starting: (2026, 8, 6)
        ).create()
        let programme = try makeProgramme()
        let enrollment = try original.enrollInGrassroots(
            programme: programme,
            consentedBy: PersonID(rawValue: "guardian-001")!
        )
        try original.recordGrassrootsSession(
            id: GrassrootsSessionID(rawValue: "session-001")!,
            participantCount: 12,
            screenedCoachCount: 1,
            durationMinutes: 60,
            safeguardingLeadPresent: true
        )
        try original.advance(by: 7)
        try original.recordGrassrootsSession(
            id: GrassrootsSessionID(rawValue: "session-002")!,
            participantCount: 18,
            screenedCoachCount: 2,
            durationMinutes: 90,
            safeguardingLeadPresent: true
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(NewLife.self, from: data)

        precondition(restored == original)
        precondition(restored.grassrootsEnrollment == enrollment)
        precondition(restored.grassrootsSessions.count == 2)
        precondition(restored.clock.elapsedDays == 7)
    }

    private static func makeProgramme() throws -> GrassrootsProgramme {
        try GrassrootsProgrammeDraft(
            id: GrassrootsProgrammeID(rawValue: "programme-001")!,
            name: "Community Football",
            activity: .communityTraining,
            participantCapacity: 24,
            screenedCoachCount: 2,
            safeguarding: SafeguardingPolicy(
                minimumParticipantAge: 8,
                maximumParticipantAge: 15,
                maxParticipantsPerScreenedCoach: 12
            )
        ).create()
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
        let protagonist = Person(
            id: PersonID(rawValue: "player-001")!,
            name: try PersonName(given: "Ada", family: "Okafor"),
            dateOfBirth: try SimulationDate(
                year: birth.0,
                month: birth.1,
                day: birth.2
            )
        )
        let guardian = Person(
            id: PersonID(rawValue: "guardian-001")!,
            name: try PersonName(given: "Nneka", family: "Okafor"),
            dateOfBirth: try SimulationDate(year: 1984, month: 4, day: 9)
        )

        return NewLifeDraft(
            personID: protagonist.id,
            name: protagonist.name,
            dateOfBirth: protagonist.dateOfBirth,
            startingDate: try SimulationDate(
                year: start.0,
                month: start.1,
                day: start.2
            ),
            household: HouseholdDraft(
                id: HouseholdID(rawValue: "household-001")!,
                members: [
                    HouseholdMember(person: protagonist, role: .protagonist),
                    HouseholdMember(person: guardian, role: .guardian),
                ],
                startingSupport: try HouseholdSupport(
                    stability: 50,
                    connection: 50,
                    availableResources: 50
                )
            )
        )
    }
}
