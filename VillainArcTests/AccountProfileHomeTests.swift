import FCTAccountProfile
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The account is the one home for the name and the birthday, and Villain Arc reads them there.
///
/// `UserProfile` carries neither — the body facts and the training self-assessment are all it
/// holds — so what these pin is the other half: that the name every surface shows comes off
/// `account.profile`'s rows, and that the age every health calculation is built from comes off the
/// account's trusted birthday and **waits** rather than defaulting while that is unknown.
@MainActor
@Suite("The account owns the name and the birthday", .serialized)
struct AccountProfileHomeTests {

    // MARK: - The name

    /// The profile sheet's heading, its avatar monogram and the toolbar badge all read this.
    @Test func theNameShownIsJoinedFromTheAccountProfileRows() throws {
        let given = AccountProfileField(kind: .givenName, value: "Fernando")
        let family = AccountProfileField(kind: .familyName, value: "Cortez")

        #expect(AccountProfileField.displayName(from: [given, family]) == "Fernando Cortez")
        // Row order is the store's, never the reading's.
        #expect(AccountProfileField.displayName(from: [family, given]) == "Fernando Cortez")
    }

    /// Clearing a field is deleting its row, so a half-filled name reads as the half that is there
    /// — and an unpulled account reads as nothing at all, which is what the monogram falls back on.
    @Test func aMissingHalfDropsOutAndNoRowsIsNoName() throws {
        let given = AccountProfileField(kind: .givenName, value: "Fernando")

        #expect(AccountProfileField.displayName(from: [given]) == "Fernando")
        #expect(AccountProfileField.displayName(from: []).isEmpty)
    }

    /// The avatar row shares the table and is not a name; it must never join into one.
    @Test func theAvatarRowIsNotPartOfTheName() throws {
        let avatar = AccountProfileField(kind: .avatarBlob, value: UUID().uuidString.lowercased())
        let given = AccountProfileField(kind: .givenName, value: "Fernando")

        #expect(AccountProfileField.displayName(from: [avatar, given]) == "Fernando")
    }

    /// The rows really are the ones a pull delivers: fetched out of a store, under the fixed uuids
    /// the server pins, they still join to the same name.
    @Test func theNameJoinsFromRowsFetchedOutOfTheStore() throws {
        let schema = Schema(AccountSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        context.insert(AccountProfileField(kind: .givenName, value: "Fernando"))
        context.insert(AccountProfileField(kind: .familyName, value: "Cortez"))
        try context.save()

        let rows = try context.fetch(FetchDescriptor<AccountProfileField>())
        #expect(AccountProfileField.displayName(from: rows) == "Fernando Cortez")
    }

    // MARK: - The birthday

    /// **A nil birthday waits; it never defaults.** Before the account onboarding completes there
    /// is no trusted row, and every age-based surface has to render nothing rather than an age
    /// pulled out of the air — the heart-rate zones the watch draws are the person's real ones or
    /// they are absent.
    @Test func anUnknownBirthdayMakesTheAgeCalculationsWait() {
        let birthdays = AccountBirthday.shared
        birthdays.forget()

        #expect(birthdays.birthday == nil)
        #expect(birthdays.age() == nil)
        #expect(birthdays.estimatedMaxHeartRate() == nil)

        birthdays.adopt(.unset)
        #expect(birthdays.age() == nil, "no trusted row is still no age")

        birthdays.adopt(.accountDeleted)
        #expect(birthdays.age() == nil, "an erased account is still no age")
    }

    /// The health math reads the account's birthday: the age is taken against the moment being
    /// rendered, so a workout from last year is scored at the age the person was that day.
    @Test func theAgeAndMaxHeartRateComeFromTheAccountsTrustedBirthday() throws {
        let birthdays = AccountBirthday.shared
        birthdays.forget()
        defer { birthdays.forget() }

        birthdays.adopt(.set(
            AccountTrustedRecord(
                birthday: CalendarDay(year: 1995, month: 1, day: 1),
                country: "US",
                setAt: .now
            ),
            remaining: AccountTrustedChangesRemaining(birthday: 2, country: 2)
        ))

        let thirtieth = try #require(
            Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 1))
        )
        #expect(birthdays.age(on: thirtieth) == 30)
        #expect(birthdays.estimatedMaxHeartRate(on: thirtieth) == 190)

        // The day before the birthday is still the younger age — whole years, never rounded up.
        let dayBefore = try #require(
            Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 31))
        )
        #expect(birthdays.age(on: dayBefore) == 29)
    }

    /// Signing out forgets it: a different account has a different birthday, and the last one left
    /// standing would draw one person's heart-rate zones for another.
    @Test func signingOutForgetsTheBirthday() {
        let birthdays = AccountBirthday.shared
        birthdays.adopt(.set(
            AccountTrustedRecord(
                birthday: CalendarDay(year: 1995, month: 1, day: 1),
                country: "US",
                setAt: .now
            ),
            remaining: AccountTrustedChangesRemaining(birthday: 2, country: 2)
        ))
        #expect(birthdays.birthday != nil)

        birthdays.forget()

        #expect(birthdays.birthday == nil)
        #expect(birthdays.estimatedMaxHeartRate() == nil)
    }

    // MARK: - Villain Arc's own profile

    /// The model itself: what is left on `UserProfile` is Villain Arc's, and its setup asks for
    /// exactly that. A profile carrying only the account's facts would be complete here — the
    /// steps that once asked for a name and a birthday are gone with the fields.
    @Test func theSetupStepsAreVillainArcsOwnFactsAlone() {
        #expect(
            UserProfileOnboardingStep.allCases == [.gender, .height, .fitnessLevel, .trainingGoal],
            "the account's facts are asked once, at the account gate, and never again here"
        )

        let profile = UserProfile()
        #expect(profile.firstMissingStep == .gender, "the first thing this app asks is its own")

        profile.gender = .male
        profile.heightCm = 177.8
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = .now
        #expect(profile.isComplete, "nothing the account owns is waited on here")
    }
}
