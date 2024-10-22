//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "TSOutgoingMessage.h"
#import "OWSOutgoingSyncMessage.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSQuotedMessage.h"
#import <SignalServiceKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

const NSUInteger kOversizeTextMessageSizeThreshold = 2 * 1024;

NSString *const kTSOutgoingMessageSentRecipientAll = @"kTSOutgoingMessageSentRecipientAll";

NSString *NSStringForOutgoingMessageState(TSOutgoingMessageState value)
{
    switch (value) {
        case TSOutgoingMessageStateSending:
            return @"TSOutgoingMessageStateSending";
        case TSOutgoingMessageStateFailed:
            return @"TSOutgoingMessageStateFailed";
        case TSOutgoingMessageStateSent_OBSOLETE:
            return @"TSOutgoingMessageStateSent_OBSOLETE";
        case TSOutgoingMessageStateDelivered_OBSOLETE:
            return @"TSOutgoingMessageStateDelivered_OBSOLETE";
        case TSOutgoingMessageStateSent:
            return @"TSOutgoingMessageStateSent";
        case TSOutgoingMessageStatePending:
            return @"TSOutgoingMessageStatePending";
    }
}

#pragma mark -

@interface TSMessage (Private)

- (void)removeAllAttachmentsWithTransaction:(SDSAnyWriteTransaction *)transaction;

@end

#pragma mark -

NSUInteger const TSOutgoingMessageSchemaVersion = 1;

@interface TSOutgoingMessage ()

@property (atomic) BOOL hasSyncedTranscript;
@property (atomic, nullable) NSString *customMessage;
@property (atomic) TSGroupMetaMessage groupMetaMessage;
@property (nonatomic, readonly) NSUInteger outgoingMessageSchemaVersion;

@property (nonatomic, readonly) TSOutgoingMessageState legacyMessageState;
@property (nonatomic, readonly) BOOL legacyWasDelivered;
@property (nonatomic, readonly) BOOL hasLegacyMessageState;

// This property is only intended to be used by GRDB queries.
@property (nonatomic, readonly) TSOutgoingMessageState storedMessageState;

@end

#pragma mark -

@implementation TSOutgoingMessage

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          sortId:(uint64_t)sortId
                       timestamp:(uint64_t)timestamp
                  uniqueThreadId:(NSString *)uniqueThreadId
                   attachmentIds:(nullable NSArray<NSString *> *)attachmentIds
                            body:(nullable NSString *)body
                      bodyRanges:(nullable MessageBodyRanges *)bodyRanges
                    contactShare:(nullable OWSContact *)contactShare
                       editState:(TSEditState)editState
                 expireStartedAt:(uint64_t)expireStartedAt
              expireTimerVersion:(nullable NSNumber *)expireTimerVersion
                       expiresAt:(uint64_t)expiresAt
                expiresInSeconds:(unsigned int)expiresInSeconds
                       giftBadge:(nullable OWSGiftBadge *)giftBadge
               isGroupStoryReply:(BOOL)isGroupStoryReply
  isSmsMessageRestoredFromBackup:(BOOL)isSmsMessageRestoredFromBackup
              isViewOnceComplete:(BOOL)isViewOnceComplete
               isViewOnceMessage:(BOOL)isViewOnceMessage
                     linkPreview:(nullable OWSLinkPreview *)linkPreview
                  messageSticker:(nullable MessageSticker *)messageSticker
                   quotedMessage:(nullable TSQuotedMessage *)quotedMessage
    storedShouldStartExpireTimer:(BOOL)storedShouldStartExpireTimer
           storyAuthorUuidString:(nullable NSString *)storyAuthorUuidString
              storyReactionEmoji:(nullable NSString *)storyReactionEmoji
                  storyTimestamp:(nullable NSNumber *)storyTimestamp
              wasRemotelyDeleted:(BOOL)wasRemotelyDeleted
                   customMessage:(nullable NSString *)customMessage
                groupMetaMessage:(TSGroupMetaMessage)groupMetaMessage
           hasLegacyMessageState:(BOOL)hasLegacyMessageState
             hasSyncedTranscript:(BOOL)hasSyncedTranscript
                  isVoiceMessage:(BOOL)isVoiceMessage
              legacyMessageState:(TSOutgoingMessageState)legacyMessageState
              legacyWasDelivered:(BOOL)legacyWasDelivered
           mostRecentFailureText:(nullable NSString *)mostRecentFailureText
          recipientAddressStates:(nullable NSDictionary<SignalServiceAddress *,TSOutgoingMessageRecipientState *> *)recipientAddressStates
              storedMessageState:(TSOutgoingMessageState)storedMessageState
            wasNotCreatedLocally:(BOOL)wasNotCreatedLocally
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId
               receivedAtTimestamp:receivedAtTimestamp
                            sortId:sortId
                         timestamp:timestamp
                    uniqueThreadId:uniqueThreadId
                     attachmentIds:attachmentIds
                              body:body
                        bodyRanges:bodyRanges
                      contactShare:contactShare
                         editState:editState
                   expireStartedAt:expireStartedAt
                expireTimerVersion:expireTimerVersion
                         expiresAt:expiresAt
                  expiresInSeconds:expiresInSeconds
                         giftBadge:giftBadge
                 isGroupStoryReply:isGroupStoryReply
    isSmsMessageRestoredFromBackup:isSmsMessageRestoredFromBackup
                isViewOnceComplete:isViewOnceComplete
                 isViewOnceMessage:isViewOnceMessage
                       linkPreview:linkPreview
                    messageSticker:messageSticker
                     quotedMessage:quotedMessage
      storedShouldStartExpireTimer:storedShouldStartExpireTimer
             storyAuthorUuidString:storyAuthorUuidString
                storyReactionEmoji:storyReactionEmoji
                    storyTimestamp:storyTimestamp
                wasRemotelyDeleted:wasRemotelyDeleted];

    if (!self) {
        return self;
    }

    _customMessage = customMessage;
    _groupMetaMessage = groupMetaMessage;
    _hasLegacyMessageState = hasLegacyMessageState;
    _hasSyncedTranscript = hasSyncedTranscript;
    _isVoiceMessage = isVoiceMessage;
    _legacyMessageState = legacyMessageState;
    _legacyWasDelivered = legacyWasDelivered;
    _mostRecentFailureText = mostRecentFailureText;
    _recipientAddressStates = recipientAddressStates;
    _storedMessageState = storedMessageState;
    _wasNotCreatedLocally = wasNotCreatedLocally;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    if (self) {
#ifndef TESTABLE_BUILD
        OWSAssertDebug(self.outgoingMessageSchemaVersion >= 1);
#endif

        _outgoingMessageSchemaVersion = TSOutgoingMessageSchemaVersion;
    }


    return self;
}

- (instancetype)initOutgoingMessageWithBuilder:(TSOutgoingMessageBuilder *)outgoingMessageBuilder
                          additionalRecipients:(NSArray<SignalServiceAddress *> *)additionalRecipients
                            explicitRecipients:(NSArray<AciObjC *> *)explicitRecipients
                             skippedRecipients:(NSArray<SignalServiceAddress *> *)skippedRecipients
                                   transaction:(SDSAnyReadTransaction *)transaction
{
    self = [super initMessageWithBuilder:outgoingMessageBuilder];
    if (!self) {
        return self;
    }

    TSThread *thread = outgoingMessageBuilder.thread;

    // New outgoing messages should immediately determine their
    // recipient list from current thread state.
    NSMutableSet<SignalServiceAddress *> *recipientAddresses = [NSMutableSet new];
    if ([self isKindOfClass:[OWSOutgoingSyncMessage class]]) {
        // Sync messages should only be sent to linked devices.
        SignalServiceAddress *localAddress = [TSAccountManagerObjcBridge localAciAddressWith:transaction];
        OWSAssertDebug(localAddress);
        [recipientAddresses addObject:localAddress];
    } else {
        // Most messages should only be sent to the current members of the group.
        [recipientAddresses addObjectsFromArray:[thread recipientAddressesWithTransaction:transaction]];
        // Some messages (eg certain call messages) go to a subset of the group.
        if (explicitRecipients.count > 0) {
            NSMutableSet<SignalServiceAddress *> *explicitRecipientAddresses = [[NSMutableSet alloc] init];
            for (AciObjC *recipientAci in explicitRecipients) {
                [explicitRecipientAddresses
                    addObject:[[SignalServiceAddress alloc] initWithServiceIdObjC:recipientAci]];
            }
            [recipientAddresses intersectSet:explicitRecipientAddresses];
        }
        // Group updates should also be sent to pending members of the group.
        if (additionalRecipients.count > 0) {
            [recipientAddresses addObjectsFromArray:additionalRecipients];
        }
    }

    NSSet<SignalServiceAddress *> *skippedRecipientsSet = [NSSet setWithArray:skippedRecipients];
    NSMutableDictionary<SignalServiceAddress *, TSOutgoingMessageRecipientState *> *recipientAddressStates =
        [NSMutableDictionary new];
    for (SignalServiceAddress *recipientAddress in recipientAddresses) {
        if (!recipientAddress.isValid) {
            OWSFailDebug(@"Ignoring invalid address.");
            continue;
        }

        OWSOutgoingMessageRecipientStatus recipientStatus = [skippedRecipientsSet containsObject:recipientAddress]
            ? OWSOutgoingMessageRecipientStatusSkipped
            : OWSOutgoingMessageRecipientStatusSending;

        TSOutgoingMessageRecipientState *recipientState =
            [[TSOutgoingMessageRecipientState alloc] initWithStatus:recipientStatus];
        recipientAddressStates[recipientAddress] = recipientState;
    }

    _recipientAddressStates = [recipientAddressStates copy];
    _groupMetaMessage = [[self class] groupMetaMessageForBuilder:outgoingMessageBuilder];
    _hasSyncedTranscript = NO;
    _outgoingMessageSchemaVersion = TSOutgoingMessageSchemaVersion;
    _changeActionsProtoData = outgoingMessageBuilder.changeActionsProtoData;
    _isVoiceMessage = outgoingMessageBuilder.isVoiceMessage;

    return self;
}

- (instancetype)initOutgoingMessageWithBuilder:(TSOutgoingMessageBuilder *)outgoingMessageBuilder
                        recipientAddressStates:
                            (NSDictionary<SignalServiceAddress *, TSOutgoingMessageRecipientState *> *)
                                recipientAddressStates
{
    self = [super initMessageWithBuilder:outgoingMessageBuilder];
    if (!self) {
        return self;
    }

    _recipientAddressStates = [recipientAddressStates copy];
    _groupMetaMessage = [[self class] groupMetaMessageForBuilder:outgoingMessageBuilder];
    _hasSyncedTranscript = NO;
    _outgoingMessageSchemaVersion = TSOutgoingMessageSchemaVersion;
    _changeActionsProtoData = outgoingMessageBuilder.changeActionsProtoData;
    _isVoiceMessage = outgoingMessageBuilder.isVoiceMessage;

    return self;
}

/// Compute the appropriate "group meta message" for a given message builder.
///
/// At the time of writing, the "meta message" property appears to be entirely
/// unused except for determining if a given `TSOutgoingMessage` should be
/// saved. It is, however, part of the `TSInteraction` database schema, so will
/// be non-trivial to do away with entirely.
///
/// - SeeAlso ``shouldBeSaved``
+ (TSGroupMetaMessage)groupMetaMessageForBuilder:(TSOutgoingMessageBuilder *)builder
{
    TSThread *thread = builder.thread;
    TSGroupMetaMessage groupMetaMessage = builder.groupMetaMessage;

    if ([thread isKindOfClass:TSGroupThread.class]) {
        // Unless specified, we assume group messages are "deliver", or "normal" messages.
        if (groupMetaMessage == TSGroupMetaMessageUnspecified) {
            return TSGroupMetaMessageDeliver;
        } else {
            return groupMetaMessage;
        }
    } else {
        // Explicit group meta message only makes sense for group threads.
        OWSAssertDebug(groupMetaMessage == TSGroupMetaMessageUnspecified);
        return TSGroupMetaMessageUnspecified;
    }
}

#pragma mark -

- (TSOutgoingMessageState)messageState
{
    TSOutgoingMessageState newMessageState =
        [TSOutgoingMessage messageStateForRecipientStates:self.recipientAddressStates.allValues];
    if (self.hasLegacyMessageState) {
        if (newMessageState == TSOutgoingMessageStateSent || self.legacyMessageState == TSOutgoingMessageStateSent) {
            return TSOutgoingMessageStateSent;
        }
    }
    return newMessageState;
}

- (BOOL)wasDeliveredToAnyRecipient
{
    if (self.deliveredRecipientAddresses.count > 0) {
        return YES;
    }
    return (self.hasLegacyMessageState && self.legacyWasDelivered && self.messageState == TSOutgoingMessageStateSent);
}

- (BOOL)wasSentToAnyRecipient
{
    if (self.sentRecipientAddresses.count > 0) {
        return YES;
    }
    return (self.hasLegacyMessageState && self.messageState == TSOutgoingMessageStateSent);
}

- (BOOL)shouldBeSaved
{
    if (!super.shouldBeSaved) {
        return NO;
    }
    if (self.groupMetaMessage == TSGroupMetaMessageDeliver || self.groupMetaMessage == TSGroupMetaMessageUnspecified) {
        return YES;
    }

    // There's no need to save this message, since it's not displayed to the user.
    //
    // Should we find a need to save this in the future, we need to exclude any non-serializable properties.
    return NO;
}

- (void)updateStoredMessageState
{
    _storedMessageState = self.messageState;
}

- (void)anyWillInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillInsertWithTransaction:transaction];

    [self updateStoredMessageState];
}

- (void)anyDidInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidInsertWithTransaction:transaction];
    [self markMessageSendLogEntryCompleteIfNeededWithTx:transaction];
}

- (void)anyWillUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillUpdateWithTransaction:transaction];

    [self updateStoredMessageState];
}

- (void)anyDidUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidUpdateWithTransaction:transaction];
    [self markMessageSendLogEntryCompleteIfNeededWithTx:transaction];
}

// This method will be called after every insert and update, so it needs
// to be cheap.
- (BOOL)shouldStartExpireTimer
{
    if (self.hasPerConversationExpirationStarted) {
        // Expiration already started.
        return YES;
    } else if (!self.hasPerConversationExpiration) {
        return NO;
    } else if (!super.shouldStartExpireTimer) {
        return NO;
    }

    return [TSOutgoingMessage isEligibleToStartExpireTimerWithMessageState:self.messageState];
}

- (BOOL)isOnline
{
    return NO;
}

- (BOOL)isUrgent
{
    return YES;
}

- (OWSInteractionType)interactionType
{
    return OWSInteractionType_OutgoingMessage;
}

#pragma mark - Update With... Methods

- (void)updateWithHasSyncedTranscript:(BOOL)hasSyncedTranscript transaction:(SDSAnyWriteTransaction *)transaction
{
    [self anyUpdateOutgoingMessageWithTransaction:transaction
                                            block:^(TSOutgoingMessage *message) {
                                                [message setHasSyncedTranscript:hasSyncedTranscript];
                                            }];
}

#pragma mark -

- (nullable SSKProtoDataMessageBuilder *)dataMessageBuilderWithThread:(TSThread *)thread
                                                          transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(thread);

    SSKProtoDataMessageBuilder *builder = [SSKProtoDataMessage builder];
    [builder setTimestamp:self.timestamp];

    NSUInteger requiredProtocolVersion = SSKProtoDataMessageProtocolVersionInitial;

    if (self.isViewOnceMessage) {
        [builder setIsViewOnce:YES];
        requiredProtocolVersion = SSKProtoDataMessageProtocolVersionViewOnceVideo;
    }

    NSString *body = self.body;
    NSString *trimmedBody = [body trimToUtf8ByteCount:(NSInteger)kOversizeTextMessageSizeThreshold];
    OWSAssertDebug(body.length == trimmedBody.length);
    [builder setBody:trimmedBody];

    NSArray<SSKProtoBodyRange *> *bodyRanges =
        [self.bodyRanges toProtoBodyRangesWithBodyLength:(NSInteger)self.body.length];
    if (bodyRanges.count > 0) {
        [builder setBodyRanges:bodyRanges];

        if (requiredProtocolVersion < SSKProtoDataMessageProtocolVersionMentions) {
            requiredProtocolVersion = SSKProtoDataMessageProtocolVersionMentions;
        }
    }

    // Story Context
    if (self.storyTimestamp && self.storyAuthorUuidString) {
        if (self.storyReactionEmoji) {
            SSKProtoDataMessageReactionBuilder *reactionBuilder =
                [SSKProtoDataMessageReaction builderWithEmoji:self.storyReactionEmoji
                                                    timestamp:self.storyTimestamp.unsignedLongLongValue];
            // ACI TODO: Use `serviceIdString` to populate this value.
            [reactionBuilder setTargetAuthorAci:self.storyAuthorUuidString];

            NSError *error;
            SSKProtoDataMessageReaction *_Nullable reaction = [reactionBuilder buildAndReturnError:&error];
            if (error || !reaction) {
                OWSFailDebug(@"Could not build story reaction protobuf: %@.", error);
            } else {
                [builder setReaction:reaction];

                if (requiredProtocolVersion < SSKProtoDataMessageProtocolVersionReactions) {
                    requiredProtocolVersion = SSKProtoDataMessageProtocolVersionReactions;
                }
            }
        }

        SSKProtoDataMessageStoryContextBuilder *storyContextBuilder = [SSKProtoDataMessageStoryContext builder];
        // ACI TODO: Use `serviceIdString` to populate this value.
        [storyContextBuilder setAuthorAci:self.storyAuthorUuidString];
        [storyContextBuilder setSentTimestamp:self.storyTimestamp.unsignedLongLongValue];

        [builder setStoryContext:[storyContextBuilder buildInfallibly]];
    }

    [builder setExpireTimer:self.expiresInSeconds];
    if (self.expireTimerVersion) {
        [builder setExpireTimerVersion:[self.expireTimerVersion unsignedIntValue]];
    } else {
        [builder setExpireTimerVersion:0];
    }


    // Group Messages
    if ([thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        OutgoingGroupProtoResult result;
        switch (groupThread.groupModel.groupsVersion) {
            case GroupsVersionV1:
                OWSLogError(@"[GV1] Cannot build data message for V1 group!");
                result = OutgoingGroupProtoResult_Error;
                break;
            case GroupsVersionV2:
                result = [self addGroupsV2ToDataMessageBuilder:builder groupThread:groupThread tx:transaction];
                break;
        }
        switch (result) {
            case OutgoingGroupProtoResult_Error:
                return nil;
            case OutgoingGroupProtoResult_AddedWithoutGroupAvatar:
                break;
        }
    }

    // Message Attachments

    // Only inserted messages should have attachments, and if they are saveable
    // they should be inserted by now.
    if ([self shouldBeSaved]) {
        if (self.grdbId != nil) {
            NSError *bodyError;
            NSArray<SSKProtoAttachmentPointer *> *attachments = [self buildProtosForBodyAttachmentsWithTx:transaction
                                                                                                    error:&bodyError];
            if (bodyError) {
                OWSFailDebug(@"Could not build body attachments");
            } else {
                [builder setAttachments:attachments];
            }
        } else {
            OWSFailDebug(@"Saved message uninserted at proto build time!");
        }
    }

    // Quoted Reply
    if (self.quotedMessage) {
        NSError *error;
        SSKProtoDataMessageQuote *_Nullable quoteProto = [self buildQuoteProtoWithQuote:self.quotedMessage
                                                                                     tx:transaction
                                                                                  error:&error];
        if (error || !quoteProto) {
            OWSFailDebug(@"Could not build quote protobuf: %@.", error);
        } else {
            [builder setQuote:quoteProto];

            if (quoteProto.bodyRanges.count > 0) {
                if (requiredProtocolVersion < SSKProtoDataMessageProtocolVersionMentions) {
                    requiredProtocolVersion = SSKProtoDataMessageProtocolVersionMentions;
                }
            }
        }
    }

    // Contact Share
    if (self.contactShare) {
        NSError *error;
        SSKProtoDataMessageContact *_Nullable contactProto = [self buildContactShareProto:self.contactShare
                                                                                       tx:transaction
                                                                                    error:&error];
        if (error || !contactProto) {
            OWSFailDebug(@"Could not build contact share protobuf: %@.", error);
        } else {
            [builder addContact:contactProto];
        }
    }

    // Link Preview
    if (self.linkPreview) {
        NSError *error;
        SSKProtoPreview *_Nullable previewProto = [self buildLinkPreviewProtoWithLinkPreview:self.linkPreview
                                                                                          tx:transaction
                                                                                       error:&error];
        if (error || !previewProto) {
            OWSFailDebug(@"Could not build link preview protobuf: %@.", error);
        } else {
            [builder addPreview:previewProto];
        }
    }

    // Sticker
    if (self.messageSticker) {
        NSError *error;
        SSKProtoDataMessageSticker *_Nullable stickerProto = [self buildStickerProtoWithSticker:self.messageSticker
                                                                                             tx:transaction
                                                                                          error:&error];
        if (error || !stickerProto) {
            OWSFailDebug(@"Could not build sticker protobuf: %@.", error);
        } else {
            [builder setSticker:stickerProto];
        }
    }

    // Gift badge
    if (self.giftBadge) {
        SSKProtoDataMessageGiftBadgeBuilder *giftBadgeBuilder = [SSKProtoDataMessageGiftBadge builder];
        [giftBadgeBuilder setReceiptCredentialPresentation:self.giftBadge.redemptionCredential];
        [builder setGiftBadge:[giftBadgeBuilder buildInfallibly]];
    }

    [builder setRequiredProtocolVersion:(uint32_t)requiredProtocolVersion];
    return builder;
}


// recipientId is nil when building "sent" sync messages for messages sent to groups.
- (nullable SSKProtoDataMessage *)buildDataMessage:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(thread);
    OWSAssertDebug([thread.uniqueId isEqualToString:self.uniqueThreadId]);
    SSKProtoDataMessageBuilder *_Nullable builder = [self dataMessageBuilderWithThread:thread transaction:transaction];
    if (!builder) {
        OWSFailDebug(@"could not build protobuf.");
        return nil;
    }

    [ProtoUtils addLocalProfileKeyIfNecessary:thread dataMessageBuilder:builder transaction:transaction];

    NSError *error;
    SSKProtoDataMessage *_Nullable dataProto = [builder buildAndReturnError:&error];
    if (error || !dataProto) {
        OWSFailDebug(@"could not build protobuf: %@", error);
        return nil;
    }
    return dataProto;
}

- (nullable SSKProtoContentBuilder *)contentBuilderWithThread:(TSThread *)thread
                                                  transaction:(SDSAnyReadTransaction *)transaction
{
    SSKProtoDataMessage *_Nullable dataMessage = [self buildDataMessage:thread transaction:transaction];
    if (!dataMessage) {
        return nil;
    }

    SSKProtoContentBuilder *contentBuilder = [SSKProtoContent builder];
    [contentBuilder setDataMessage:dataMessage];
    return contentBuilder;
}

- (nullable NSData *)buildPlainTextData:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction
{
    SSKProtoContentBuilder *_Nullable contentBuilder = [self contentBuilderWithThread:thread transaction:transaction];
    if (!contentBuilder) {
        OWSFailDebug(@"could not build protobuf.");
        return nil;
    }

    [contentBuilder setPniSignatureMessage:[self buildPniSignatureMessageIfNeededWithTransaction:transaction]];

    NSError *error;
    NSData *_Nullable contentData = [contentBuilder buildSerializedDataAndReturnError:&error];
    if (error || !contentData) {
        OWSFailDebug(@"could not serialize protobuf: %@", error);
        return nil;
    }
    return contentData;
}

- (BOOL)shouldSyncTranscript
{
    return YES;
}

- (nullable OWSOutgoingSyncMessage *)buildTranscriptSyncMessageWithLocalThread:(TSThread *)localThread
                                                                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(self.shouldSyncTranscript);

    TSThread *messageThread = [self threadWithTx:transaction];
    if (messageThread == nil) {
        return nil;
    }

    return [[OWSOutgoingSentMessageTranscript alloc] initWithLocalThread:localThread
                                                           messageThread:messageThread
                                                         outgoingMessage:self
                                                       isRecipientUpdate:self.hasSyncedTranscript
                                                             transaction:transaction];
}

@end

NS_ASSUME_NONNULL_END
