import Foundation

/// A calendar day in the simulation's proleptic Gregorian timeline.
///
/// Keeping time as date components prevents device time zones and daylight-saving
/// changes from moving a save to another day.
public struct SimulationDate: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        let components = DateComponents(
            calendar: Self.calendar,
            timeZone: Self.timeZone,
            year: year,
            month: month,
            day: day
        )

        guard
            let date = Self.calendar.date(from: components),
            Self.calendar.dateComponents([.year, .month, .day], from: date)
                == DateComponents(year: year, month: month, day: day)
        else {
            throw SimulationTimeError.invalidDate(year: year, month: month, day: day)
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func adding(days: Int) throws -> Self {
        guard let result = Self.calendar.date(byAdding: .day, value: days, to: foundationDate) else {
            throw SimulationTimeError.dateArithmeticFailed
        }
        return try Self(date: result)
    }

    public func days(until other: Self) -> Int {
        Self.calendar.dateComponents([.day], from: foundationDate, to: other.foundationDate).day ?? 0
    }

    private init(date: Date) throws {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            throw SimulationTimeError.dateArithmeticFailed
        }
        try self.init(year: year, month: month, day: day)
    }

    private var foundationDate: Date {
        Self.calendar.date(
            from: DateComponents(
                calendar: Self.calendar,
                timeZone: Self.timeZone,
                year: year,
                month: month,
                day: day
            )
        )!
    }

    private static let timeZone = TimeZone(secondsFromGMT: 0)!
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

public enum SimulationTimeError: Error, Equatable, Sendable {
    case invalidDate(year: Int, month: Int, day: Int)
    case negativeAdvance(Int)
    case cannotReverse(from: SimulationDate, to: SimulationDate)
    case dateArithmeticFailed
}

/// The single source of truth for elapsed simulation time.
public struct SimulationClock: Codable, Hashable, Sendable {
    public private(set) var currentDate: SimulationDate
    public private(set) var elapsedDays: Int

    public init(startingOn date: SimulationDate) {
        currentDate = date
        elapsedDays = 0
    }

    @discardableResult
    public mutating func advance(by days: Int = 1) throws -> SimulationDate {
        guard days >= 0 else {
            throw SimulationTimeError.negativeAdvance(days)
        }
        currentDate = try currentDate.adding(days: days)
        elapsedDays += days
        return currentDate
    }

    @discardableResult
    public mutating func advance(to date: SimulationDate) throws -> SimulationDate {
        guard date >= currentDate else {
            throw SimulationTimeError.cannotReverse(from: currentDate, to: date)
        }
        return try advance(by: currentDate.days(until: date))
    }
}

public struct PersonID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

public struct PersonName: Codable, Hashable, Sendable {
    public let given: String
    public let family: String

    public init(given: String, family: String) throws {
        let given = given.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = family.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !given.isEmpty, !family.isEmpty else {
            throw PersonError.incompleteName
        }
        self.given = given
        self.family = family
    }

    public var full: String {
        "\(given) \(family)"
    }
}

public enum LifeStage: String, Codable, CaseIterable, Sendable {
    case childhood
    case adolescence
    case adulthood
    case laterLife
}

public enum PersonError: Error, Equatable, Sendable {
    case incompleteName
    case datePrecedesBirth(reference: SimulationDate, birth: SimulationDate)
}

/// A stable human identity whose age is derived from the simulation clock.
public struct Person: Identifiable, Codable, Hashable, Sendable {
    public let id: PersonID
    public var name: PersonName
    public let dateOfBirth: SimulationDate

    public init(id: PersonID, name: PersonName, dateOfBirth: SimulationDate) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
    }

    public func age(on date: SimulationDate) throws -> Int {
        guard date >= dateOfBirth else {
            throw PersonError.datePrecedesBirth(reference: date, birth: dateOfBirth)
        }

        let birthdayHasOccurred =
            (date.month, date.day) >= (dateOfBirth.month, dateOfBirth.day)
        return date.year - dateOfBirth.year - (birthdayHasOccurred ? 0 : 1)
    }

    public func lifeStage(on date: SimulationDate) throws -> LifeStage {
        switch try age(on: date) {
        case 0...12:
            return .childhood
        case 13...17:
            return .adolescence
        case 18...64:
            return .adulthood
        default:
            return .laterLife
        }
    }
}

public struct HouseholdID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

public enum HouseholdRole: String, Codable, CaseIterable, Sendable {
    case protagonist
    case guardian
    case sibling
    case relative
}

public struct HouseholdMember: Codable, Hashable, Sendable {
    public let person: Person
    public let role: HouseholdRole

    public init(person: Person, role: HouseholdRole) {
        self.person = person
        self.role = role
    }
}

public enum HouseholdError: Error, Equatable, Sendable {
    case duplicateMember(PersonID)
    case missingProtagonist(PersonID)
    case protagonistRoleMustBeUnique
    case missingAdultGuardian
    case memberBornAfterStart(PersonID)
    case scoreOutsideRange(Int)
}

/// The household conditions directly affected by early-life decisions.
///
/// Values are bounded summaries rather than personality attributes. They record
/// the current capacity of the home, not a judgement about a family structure.
public struct HouseholdSupport: Codable, Hashable, Sendable {
    public let stability: Int
    public let connection: Int
    public let availableResources: Int

    public init(stability: Int, connection: Int, availableResources: Int) throws {
        for score in [stability, connection, availableResources] {
            guard (0...100).contains(score) else {
                throw HouseholdError.scoreOutsideRange(score)
            }
        }
        self.stability = stability
        self.connection = connection
        self.availableResources = availableResources
    }

    fileprivate func applying(_ impact: ChildhoodImpact) -> Self {
        Self(
            boundedStability: Self.clamp(stability + impact.stability),
            boundedConnection: Self.clamp(connection + impact.connection),
            boundedAvailableResources: Self.clamp(availableResources + impact.availableResources)
        )
    }

    private init(
        boundedStability: Int,
        boundedConnection: Int,
        boundedAvailableResources: Int
    ) {
        stability = boundedStability
        connection = boundedConnection
        availableResources = boundedAvailableResources
    }

    private static func clamp(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private enum CodingKeys: String, CodingKey {
        case stability
        case connection
        case availableResources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stability = try container.decode(Int.self, forKey: .stability)
        let connection = try container.decode(Int.self, forKey: .connection)
        let availableResources = try container.decode(Int.self, forKey: .availableResources)

        do {
            try self.init(
                stability: stability,
                connection: connection,
                availableResources: availableResources
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .stability,
                in: container,
                debugDescription: "Household support scores must be between 0 and 100."
            )
        }
    }
}

public struct HouseholdDraft: Codable, Hashable, Sendable {
    public let id: HouseholdID
    public var members: [HouseholdMember]
    public var startingSupport: HouseholdSupport

    public init(
        id: HouseholdID,
        members: [HouseholdMember],
        startingSupport: HouseholdSupport
    ) {
        self.id = id
        self.members = members
        self.startingSupport = startingSupport
    }

    public func create(protagonist: Person, on date: SimulationDate) throws -> Household {
        try Household.validate(members: members, protagonist: protagonist, on: date)
        return Household(id: id, members: members, support: startingSupport)
    }
}

public struct Household: Codable, Hashable, Sendable {
    public let id: HouseholdID
    public let members: [HouseholdMember]
    public fileprivate(set) var support: HouseholdSupport

    fileprivate init(id: HouseholdID, members: [HouseholdMember], support: HouseholdSupport) {
        self.id = id
        self.members = members
        self.support = support
    }

    fileprivate static func validate(
        members: [HouseholdMember],
        protagonist: Person,
        on date: SimulationDate
    ) throws {
        var personIDs = Set<PersonID>()
        for member in members {
            guard personIDs.insert(member.person.id).inserted else {
                throw HouseholdError.duplicateMember(member.person.id)
            }
            guard member.person.dateOfBirth <= date else {
                throw HouseholdError.memberBornAfterStart(member.person.id)
            }
        }

        let protagonistMembers = members.filter { $0.role == .protagonist }
        guard protagonistMembers.count == 1 else {
            throw HouseholdError.protagonistRoleMustBeUnique
        }
        guard protagonistMembers[0].person == protagonist else {
            throw HouseholdError.missingProtagonist(protagonist.id)
        }

        let hasAdultGuardian = try members.contains { member in
            guard member.role == .guardian else { return false }
            return try member.person.age(on: date) >= 18
        }
        guard hasAdultGuardian else {
            throw HouseholdError.missingAdultGuardian
        }
    }

    fileprivate mutating func apply(_ impact: ChildhoodImpact) {
        support = support.applying(impact)
    }
}

public struct ChildhoodDecisionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

public enum ChildhoodChoice: String, Codable, CaseIterable, Sendable {
    case shareResponsibilities
    case keepASteadyRoutine
    case joinACommunityActivity
    case protectQuietTime

    fileprivate var impact: ChildhoodImpact {
        switch self {
        case .shareResponsibilities:
            return ChildhoodImpact(stability: 3, connection: 5, availableResources: -1)
        case .keepASteadyRoutine:
            return ChildhoodImpact(stability: 5, connection: 2, availableResources: -1)
        case .joinACommunityActivity:
            return ChildhoodImpact(stability: 1, connection: 4, availableResources: -3)
        case .protectQuietTime:
            return ChildhoodImpact(stability: 2, connection: 1, availableResources: 1)
        }
    }
}

public struct ChildhoodImpact: Codable, Hashable, Sendable {
    public let stability: Int
    public let connection: Int
    public let availableResources: Int

    fileprivate init(stability: Int, connection: Int, availableResources: Int) {
        self.stability = stability
        self.connection = connection
        self.availableResources = availableResources
    }
}

/// An inspectable, append-only explanation of one early-life choice.
public struct ChildhoodDecision: Codable, Hashable, Sendable {
    public let id: ChildhoodDecisionID
    public let date: SimulationDate
    public let choice: ChildhoodChoice
    public let impact: ChildhoodImpact
    public let supportBefore: HouseholdSupport
    public let supportAfter: HouseholdSupport
}

public enum ChildhoodDecisionError: Error, Equatable, Sendable {
    case requiresChildhood(currentStage: LifeStage)
    case duplicateID(ChildhoodDecisionID)
    case decisionAlreadyRecorded(on: SimulationDate)
}

public struct GrassrootsProgrammeID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

public enum GrassrootsActivity: String, Codable, CaseIterable, Sendable {
    case communityTraining
    case schoolFootball
    case openPlay
}

public enum GrassrootsError: Error, Equatable, Sendable {
    case incompleteProgrammeName
    case invalidParticipantCapacity(Int)
    case invalidCoachRatio(Int)
    case invalidAgeRange(minimum: Int, maximum: Int)
    case insufficientScreenedCoaches(required: Int, available: Int)
    case alreadyEnrolled(GrassrootsProgrammeID)
    case ageOutsideProgrammeRange(age: Int, minimum: Int, maximum: Int)
    case guardianConsentRequired(PersonID)
    case noGrassrootsEnrollment
    case duplicateSessionID(GrassrootsSessionID)
    case sessionAlreadyRecorded(on: SimulationDate)
    case sessionBeforeEnrollment
    case participantCountOutsideCapacity(Int)
    case invalidSessionDuration(Int)
    case safeguardingLeadRequired
}

/// Minimum, explicit safety requirements for a youth football programme.
public struct SafeguardingPolicy: Codable, Hashable, Sendable {
    public let minimumParticipantAge: Int
    public let maximumParticipantAge: Int
    public let maxParticipantsPerScreenedCoach: Int

    public init(
        minimumParticipantAge: Int = 5,
        maximumParticipantAge: Int = 17,
        maxParticipantsPerScreenedCoach: Int = 12
    ) throws {
        guard
            minimumParticipantAge >= 0,
            maximumParticipantAge <= 17,
            minimumParticipantAge <= maximumParticipantAge
        else {
            throw GrassrootsError.invalidAgeRange(
                minimum: minimumParticipantAge,
                maximum: maximumParticipantAge
            )
        }
        guard (1...16).contains(maxParticipantsPerScreenedCoach) else {
            throw GrassrootsError.invalidCoachRatio(maxParticipantsPerScreenedCoach)
        }

        self.minimumParticipantAge = minimumParticipantAge
        self.maximumParticipantAge = maximumParticipantAge
        self.maxParticipantsPerScreenedCoach = maxParticipantsPerScreenedCoach
    }

    fileprivate func requiredCoachCount(for participants: Int) -> Int {
        (participants + maxParticipantsPerScreenedCoach - 1)
            / maxParticipantsPerScreenedCoach
    }
}

public struct GrassrootsProgrammeDraft: Codable, Hashable, Sendable {
    public let id: GrassrootsProgrammeID
    public var name: String
    public let activity: GrassrootsActivity
    public var participantCapacity: Int
    public var screenedCoachCount: Int
    public var safeguarding: SafeguardingPolicy

    public init(
        id: GrassrootsProgrammeID,
        name: String,
        activity: GrassrootsActivity,
        participantCapacity: Int,
        screenedCoachCount: Int,
        safeguarding: SafeguardingPolicy
    ) {
        self.id = id
        self.name = name
        self.activity = activity
        self.participantCapacity = participantCapacity
        self.screenedCoachCount = screenedCoachCount
        self.safeguarding = safeguarding
    }

    public func create() throws -> GrassrootsProgramme {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeguarding = try SafeguardingPolicy(
            minimumParticipantAge: safeguarding.minimumParticipantAge,
            maximumParticipantAge: safeguarding.maximumParticipantAge,
            maxParticipantsPerScreenedCoach: safeguarding.maxParticipantsPerScreenedCoach
        )
        guard !name.isEmpty else {
            throw GrassrootsError.incompleteProgrammeName
        }
        guard participantCapacity > 0 else {
            throw GrassrootsError.invalidParticipantCapacity(participantCapacity)
        }

        let required = safeguarding.requiredCoachCount(for: participantCapacity)
        guard screenedCoachCount >= required else {
            throw GrassrootsError.insufficientScreenedCoaches(
                required: required,
                available: screenedCoachCount
            )
        }

        return GrassrootsProgramme(
            id: id,
            name: name,
            activity: activity,
            participantCapacity: participantCapacity,
            screenedCoachCount: screenedCoachCount,
            safeguarding: safeguarding
        )
    }
}

public struct GrassrootsProgramme: Codable, Hashable, Sendable {
    public let id: GrassrootsProgrammeID
    public let name: String
    public let activity: GrassrootsActivity
    public let participantCapacity: Int
    public let screenedCoachCount: Int
    public let safeguarding: SafeguardingPolicy

    fileprivate init(
        id: GrassrootsProgrammeID,
        name: String,
        activity: GrassrootsActivity,
        participantCapacity: Int,
        screenedCoachCount: Int,
        safeguarding: SafeguardingPolicy
    ) {
        self.id = id
        self.name = name
        self.activity = activity
        self.participantCapacity = participantCapacity
        self.screenedCoachCount = screenedCoachCount
        self.safeguarding = safeguarding
    }

    fileprivate func validate() throws {
        let rebuilt = try GrassrootsProgrammeDraft(
            id: id,
            name: name,
            activity: activity,
            participantCapacity: participantCapacity,
            screenedCoachCount: screenedCoachCount,
            safeguarding: safeguarding
        ).create()
        guard rebuilt == self else {
            throw GrassrootsError.incompleteProgrammeName
        }
    }
}

public struct GrassrootsEnrollment: Codable, Hashable, Sendable {
    public let programme: GrassrootsProgramme
    public let enrolledOn: SimulationDate
    public let consentedBy: PersonID
}

public struct GrassrootsSessionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

/// An auditable attendance record with the supervision facts checked at entry.
public struct GrassrootsSession: Codable, Hashable, Sendable {
    public let id: GrassrootsSessionID
    public let date: SimulationDate
    public let participantCount: Int
    public let screenedCoachCount: Int
    public let durationMinutes: Int
    public let safeguardingLeadPresent: Bool
}

public enum NewLifeError: Error, Equatable, Sendable {
    case startsBeforeBirth(start: SimulationDate, birth: SimulationDate)
}

/// The player-selected facts required to begin a life.
///
/// Date of birth is captured as a complete calendar date. Age is deliberately
/// omitted because it is derived from that date and the simulation clock.
public struct NewLifeDraft: Codable, Hashable, Sendable {
    public let personID: PersonID
    public var name: PersonName
    public let dateOfBirth: SimulationDate
    public let startingDate: SimulationDate
    public var household: HouseholdDraft

    public init(
        personID: PersonID,
        name: PersonName,
        dateOfBirth: SimulationDate,
        startingDate: SimulationDate,
        household: HouseholdDraft
    ) {
        self.personID = personID
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.startingDate = startingDate
        self.household = household
    }

    public func create() throws -> NewLife {
        guard startingDate >= dateOfBirth else {
            throw NewLifeError.startsBeforeBirth(
                start: startingDate,
                birth: dateOfBirth
            )
        }

        let protagonist = Person(id: personID, name: name, dateOfBirth: dateOfBirth)
        let household = try household.create(protagonist: protagonist, on: startingDate)

        return NewLife(
            protagonist: protagonist,
            clock: SimulationClock(startingOn: startingDate),
            household: household,
            childhoodDecisions: [],
            grassrootsEnrollment: nil,
            grassrootsSessions: []
        )
    }
}

/// A newly-created playable life with one authoritative person and clock.
public struct NewLife: Codable, Hashable, Sendable {
    public let protagonist: Person
    public private(set) var clock: SimulationClock
    public private(set) var household: Household
    public private(set) var childhoodDecisions: [ChildhoodDecision]
    public private(set) var grassrootsEnrollment: GrassrootsEnrollment?
    public private(set) var grassrootsSessions: [GrassrootsSession]

    private enum CodingKeys: String, CodingKey {
        case protagonist
        case clock
        case household
        case childhoodDecisions
        case grassrootsEnrollment
        case grassrootsSessions
    }

    fileprivate init(
        protagonist: Person,
        clock: SimulationClock,
        household: Household,
        childhoodDecisions: [ChildhoodDecision],
        grassrootsEnrollment: GrassrootsEnrollment?,
        grassrootsSessions: [GrassrootsSession]
    ) {
        self.protagonist = protagonist
        self.clock = clock
        self.household = household
        self.childhoodDecisions = childhoodDecisions
        self.grassrootsEnrollment = grassrootsEnrollment
        self.grassrootsSessions = grassrootsSessions
    }

    public var age: Int {
        let date = clock.currentDate
        let birth = protagonist.dateOfBirth
        let birthdayHasOccurred = (date.month, date.day) >= (birth.month, birth.day)
        return date.year - birth.year - (birthdayHasOccurred ? 0 : 1)
    }

    @discardableResult
    public mutating func advance(by days: Int = 1) throws -> SimulationDate {
        try clock.advance(by: days)
    }

    @discardableResult
    public mutating func recordChildhoodDecision(
        id: ChildhoodDecisionID,
        choice: ChildhoodChoice
    ) throws -> ChildhoodDecision {
        let stage = try protagonist.lifeStage(on: clock.currentDate)
        guard stage == .childhood else {
            throw ChildhoodDecisionError.requiresChildhood(currentStage: stage)
        }
        guard !childhoodDecisions.contains(where: { $0.id == id }) else {
            throw ChildhoodDecisionError.duplicateID(id)
        }
        guard !childhoodDecisions.contains(where: { $0.date == clock.currentDate }) else {
            throw ChildhoodDecisionError.decisionAlreadyRecorded(on: clock.currentDate)
        }

        let before = household.support
        let impact = choice.impact
        household.apply(impact)
        let decision = ChildhoodDecision(
            id: id,
            date: clock.currentDate,
            choice: choice,
            impact: impact,
            supportBefore: before,
            supportAfter: household.support
        )
        childhoodDecisions.append(decision)
        return decision
    }

    @discardableResult
    public mutating func enrollInGrassroots(
        programme: GrassrootsProgramme,
        consentedBy guardianID: PersonID
    ) throws -> GrassrootsEnrollment {
        if let grassrootsEnrollment {
            throw GrassrootsError.alreadyEnrolled(grassrootsEnrollment.programme.id)
        }

        try programme.validate()
        try Self.validateParticipantAge(
            protagonist: protagonist,
            on: clock.currentDate,
            for: programme.safeguarding
        )
        try Self.validateGuardianConsent(
            guardianID,
            in: household,
            on: clock.currentDate
        )

        let enrollment = GrassrootsEnrollment(
            programme: programme,
            enrolledOn: clock.currentDate,
            consentedBy: guardianID
        )
        grassrootsEnrollment = enrollment
        return enrollment
    }

    @discardableResult
    public mutating func recordGrassrootsSession(
        id: GrassrootsSessionID,
        participantCount: Int,
        screenedCoachCount: Int,
        durationMinutes: Int,
        safeguardingLeadPresent: Bool
    ) throws -> GrassrootsSession {
        guard let enrollment = grassrootsEnrollment else {
            throw GrassrootsError.noGrassrootsEnrollment
        }
        guard !grassrootsSessions.contains(where: { $0.id == id }) else {
            throw GrassrootsError.duplicateSessionID(id)
        }
        guard !grassrootsSessions.contains(where: { $0.date == clock.currentDate }) else {
            throw GrassrootsError.sessionAlreadyRecorded(on: clock.currentDate)
        }

        let session = GrassrootsSession(
            id: id,
            date: clock.currentDate,
            participantCount: participantCount,
            screenedCoachCount: screenedCoachCount,
            durationMinutes: durationMinutes,
            safeguardingLeadPresent: safeguardingLeadPresent
        )
        try Self.validate(
            session: session,
            enrollment: enrollment,
            protagonist: protagonist
        )
        grassrootsSessions.append(session)
        return session
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let protagonist = try container.decode(Person.self, forKey: .protagonist)
        let clock = try container.decode(SimulationClock.self, forKey: .clock)
        let household = try container.decode(Household.self, forKey: .household)
        let childhoodDecisions = try container.decode(
            [ChildhoodDecision].self,
            forKey: .childhoodDecisions
        )
        let grassrootsEnrollment = try container.decodeIfPresent(
            GrassrootsEnrollment.self,
            forKey: .grassrootsEnrollment
        )
        let grassrootsSessions = try container.decodeIfPresent(
            [GrassrootsSession].self,
            forKey: .grassrootsSessions
        ) ?? []

        guard clock.currentDate >= protagonist.dateOfBirth else {
            throw DecodingError.dataCorruptedError(
                forKey: .clock,
                in: container,
                debugDescription: "A new life's clock cannot precede its date of birth."
            )
        }


        do {
            try Household.validate(
                members: household.members,
                protagonist: protagonist,
                on: clock.currentDate
            )
            try Self.validate(
                childhoodDecisions: childhoodDecisions,
                protagonist: protagonist,
                clock: clock,
                household: household
            )
            try Self.validate(
                enrollment: grassrootsEnrollment,
                sessions: grassrootsSessions,
                protagonist: protagonist,
                clock: clock,
                household: household
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .household,
                in: container,
                debugDescription: "The household, childhood history, or grassroots history is inconsistent."
            )
        }

        self.protagonist = protagonist
        self.clock = clock
        self.household = household
        self.childhoodDecisions = childhoodDecisions
        self.grassrootsEnrollment = grassrootsEnrollment
        self.grassrootsSessions = grassrootsSessions
    }

    private static func validate(
        childhoodDecisions: [ChildhoodDecision],
        protagonist: Person,
        clock: SimulationClock,
        household: Household
    ) throws {
        var ids = Set<ChildhoodDecisionID>()
        var dates = Set<SimulationDate>()
        var previousSupport: HouseholdSupport?
        var previousDate: SimulationDate?

        for decision in childhoodDecisions {
            guard ids.insert(decision.id).inserted else {
                throw ChildhoodDecisionError.duplicateID(decision.id)
            }
            guard dates.insert(decision.date).inserted else {
                throw ChildhoodDecisionError.decisionAlreadyRecorded(on: decision.date)
            }
            guard
                decision.date >= protagonist.dateOfBirth,
                decision.date <= clock.currentDate,
                try protagonist.lifeStage(on: decision.date) == .childhood,
                decision.impact == decision.choice.impact,
                decision.supportAfter == decision.supportBefore.applying(decision.impact),
                previousSupport == nil || previousSupport == decision.supportBefore,
                previousDate == nil || previousDate! < decision.date
            else {
                throw ChildhoodDecisionError.requiresChildhood(
                    currentStage: try protagonist.lifeStage(on: clock.currentDate)
                )
            }
            previousSupport = decision.supportAfter
            previousDate = decision.date
        }

        if let previousSupport {
            guard previousSupport == household.support else {
                throw ChildhoodDecisionError.requiresChildhood(
                    currentStage: try protagonist.lifeStage(on: clock.currentDate)
                )
            }
        }
    }

    private static func validate(
        enrollment: GrassrootsEnrollment?,
        sessions: [GrassrootsSession],
        protagonist: Person,
        clock: SimulationClock,
        household: Household
    ) throws {
        guard let enrollment else {
            guard sessions.isEmpty else {
                throw GrassrootsError.noGrassrootsEnrollment
            }
            return
        }

        try enrollment.programme.validate()
        guard enrollment.enrolledOn <= clock.currentDate else {
            throw GrassrootsError.sessionBeforeEnrollment
        }
        try validateParticipantAge(
            protagonist: protagonist,
            on: enrollment.enrolledOn,
            for: enrollment.programme.safeguarding
        )
        try validateGuardianConsent(
            enrollment.consentedBy,
            in: household,
            on: enrollment.enrolledOn
        )

        var ids = Set<GrassrootsSessionID>()
        var dates = Set<SimulationDate>()
        var previousDate: SimulationDate?
        for session in sessions {
            guard ids.insert(session.id).inserted else {
                throw GrassrootsError.duplicateSessionID(session.id)
            }
            guard dates.insert(session.date).inserted else {
                throw GrassrootsError.sessionAlreadyRecorded(on: session.date)
            }
            guard
                session.date >= enrollment.enrolledOn,
                session.date <= clock.currentDate,
                previousDate == nil || previousDate! < session.date
            else {
                throw GrassrootsError.sessionBeforeEnrollment
            }
            try validate(
                session: session,
                enrollment: enrollment,
                protagonist: protagonist
            )
            previousDate = session.date
        }
    }

    private static func validate(
        session: GrassrootsSession,
        enrollment: GrassrootsEnrollment,
        protagonist: Person
    ) throws {
        guard session.date >= enrollment.enrolledOn else {
            throw GrassrootsError.sessionBeforeEnrollment
        }
        try validateParticipantAge(
            protagonist: protagonist,
            on: session.date,
            for: enrollment.programme.safeguarding
        )
        guard
            (1...enrollment.programme.participantCapacity)
                .contains(session.participantCount)
        else {
            throw GrassrootsError.participantCountOutsideCapacity(
                session.participantCount
            )
        }
        guard (30...180).contains(session.durationMinutes) else {
            throw GrassrootsError.invalidSessionDuration(session.durationMinutes)
        }
        guard session.safeguardingLeadPresent else {
            throw GrassrootsError.safeguardingLeadRequired
        }

        let required = enrollment.programme.safeguarding
            .requiredCoachCount(for: session.participantCount)
        let available = min(
            session.screenedCoachCount,
            enrollment.programme.screenedCoachCount
        )
        guard session.screenedCoachCount <= enrollment.programme.screenedCoachCount,
              available >= required else {
            throw GrassrootsError.insufficientScreenedCoaches(
                required: required,
                available: available
            )
        }
    }

    private static func validateParticipantAge(
        protagonist: Person,
        on date: SimulationDate,
        for policy: SafeguardingPolicy
    ) throws {
        let age = try protagonist.age(on: date)
        guard (policy.minimumParticipantAge...policy.maximumParticipantAge).contains(age) else {
            throw GrassrootsError.ageOutsideProgrammeRange(
                age: age,
                minimum: policy.minimumParticipantAge,
                maximum: policy.maximumParticipantAge
            )
        }
    }

    private static func validateGuardianConsent(
        _ guardianID: PersonID,
        in household: Household,
        on date: SimulationDate
    ) throws {
        let guardian = household.members.first {
            $0.person.id == guardianID && $0.role == .guardian
        }
        guard let guardian, try guardian.person.age(on: date) >= 18 else {
            throw GrassrootsError.guardianConsentRequired(guardianID)
        }
    }
}
