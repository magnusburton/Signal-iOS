//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import <SignalServiceKit/TSThread.h>

NS_ASSUME_NONNULL_BEGIN

@class SignalServiceAddress;

@interface TSContactThread : TSThread

/// Represents the uppercase ServiceId string for this contact.
/// - Note
/// This property name includes `UUID` for compatibility with SDS (to match the
/// SQLite column), but **may not contain a valid UUID string**.
@property (nonatomic, nullable) NSString *contactUUID;
@property (nonatomic, nullable) NSString *contactPhoneNumber;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUniqueId:(NSString *)uniqueId NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

// TODO: We might want to make this initializer private once we
//       convert getOrCreateThreadWithContactAddress to take "any" transaction.
- (instancetype)initWithContactAddress:(SignalServiceAddress *)contactAddress NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithGrdbId:(int64_t)grdbId
                                       uniqueId:(NSString *)uniqueId
                  conversationColorNameObsolete:(NSString *)conversationColorNameObsolete
                                   creationDate:(nullable NSDate *)creationDate
                             isArchivedObsolete:(BOOL)isArchivedObsolete
                         isMarkedUnreadObsolete:(BOOL)isMarkedUnreadObsolete
                           lastInteractionRowId:(int64_t)lastInteractionRowId
                      lastVisibleSortIdObsolete:(uint64_t)lastVisibleSortIdObsolete
    lastVisibleSortIdOnScreenPercentageObsolete:(double)lastVisibleSortIdOnScreenPercentageObsolete
                        mentionNotificationMode:(TSThreadMentionNotificationMode)mentionNotificationMode
                                   messageDraft:(nullable NSString *)messageDraft
                         messageDraftBodyRanges:(nullable MessageBodyRanges *)messageDraftBodyRanges
                         mutedUntilDateObsolete:(nullable NSDate *)mutedUntilDateObsolete
                    mutedUntilTimestampObsolete:(uint64_t)mutedUntilTimestampObsolete
                          shouldThreadBeVisible:(BOOL)shouldThreadBeVisible NS_UNAVAILABLE;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
   conversationColorNameObsolete:(NSString *)conversationColorNameObsolete
                    creationDate:(nullable NSDate *)creationDate
             editTargetTimestamp:(nullable NSNumber *)editTargetTimestamp
              isArchivedObsolete:(BOOL)isArchivedObsolete
          isMarkedUnreadObsolete:(BOOL)isMarkedUnreadObsolete
            lastInteractionRowId:(uint64_t)lastInteractionRowId
          lastSentStoryTimestamp:(nullable NSNumber *)lastSentStoryTimestamp
       lastVisibleSortIdObsolete:(uint64_t)lastVisibleSortIdObsolete
lastVisibleSortIdOnScreenPercentageObsolete:(double)lastVisibleSortIdOnScreenPercentageObsolete
         mentionNotificationMode:(TSThreadMentionNotificationMode)mentionNotificationMode
                    messageDraft:(nullable NSString *)messageDraft
          messageDraftBodyRanges:(nullable MessageBodyRanges *)messageDraftBodyRanges
          mutedUntilDateObsolete:(nullable NSDate *)mutedUntilDateObsolete
     mutedUntilTimestampObsolete:(uint64_t)mutedUntilTimestampObsolete
           shouldThreadBeVisible:(BOOL)shouldThreadBeVisible
                   storyViewMode:(TSThreadStoryViewMode)storyViewMode
              contactPhoneNumber:(nullable NSString *)contactPhoneNumber
                     contactUUID:(nullable NSString *)contactUUID
              hasDismissedOffers:(BOOL)hasDismissedOffers
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:conversationColorNameObsolete:creationDate:editTargetTimestamp:isArchivedObsolete:isMarkedUnreadObsolete:lastInteractionRowId:lastSentStoryTimestamp:lastVisibleSortIdObsolete:lastVisibleSortIdOnScreenPercentageObsolete:mentionNotificationMode:messageDraft:messageDraftBodyRanges:mutedUntilDateObsolete:mutedUntilTimestampObsolete:shouldThreadBeVisible:storyViewMode:contactPhoneNumber:contactUUID:hasDismissedOffers:));

// clang-format on

// --- CODE GENERATION MARKER

@property (nonatomic, readonly) SignalServiceAddress *contactAddress;
@property (nonatomic) BOOL hasDismissedOffers; // deprecated

+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
    NS_SWIFT_NAME(getOrCreateThread(contactAddress:));

+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                        transaction:(SDSAnyWriteTransaction *)transaction;

// Unlike getOrCreateThreadWithContactAddress, this will _NOT_ create a thread if one does not already exist.
+ (nullable instancetype)getThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                         transaction:(SDSAnyReadTransaction *)transaction;

+ (nullable SignalServiceAddress *)contactAddressFromThreadId:(NSString *)threadId
                                                  transaction:(SDSAnyReadTransaction *)transaction;

// This is only ever used from migration from a pre-UUID world to a UUID world
+ (nullable NSString *)legacyContactPhoneNumberFromThreadId:(NSString *)threadId;

@end

NS_ASSUME_NONNULL_END
