//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "TSInvalidIdentityKeyReceivingErrorMessage.h"
#import "TSContactThread.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

/* DEPRECATED */ @interface TSInvalidIdentityKeyReceivingErrorMessage ()

@property (nonatomic, readonly, copy) NSString *authorId;

@property (atomic, nullable) NSData *envelopeData;

@end

#pragma mark -

@implementation TSInvalidIdentityKeyReceivingErrorMessage {
    // Not using a property declaration in order to exclude from DB serialization
    SSKProtoEnvelope *_Nullable _envelope;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

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
                       errorType:(TSErrorMessageType)errorType
                            read:(BOOL)read
                recipientAddress:(nullable SignalServiceAddress *)recipientAddress
                          sender:(nullable SignalServiceAddress *)sender
             wasIdentityVerified:(BOOL)wasIdentityVerified
                        authorId:(NSString *)authorId
                    envelopeData:(nullable NSData *)envelopeData
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
                wasRemotelyDeleted:wasRemotelyDeleted
                         errorType:errorType
                              read:read
                  recipientAddress:recipientAddress
                            sender:sender
               wasIdentityVerified:wasIdentityVerified];

    if (!self) {
        return self;
    }

    _authorId = authorId;
    _envelopeData = envelopeData;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (nullable SSKProtoEnvelope *)envelope
{
    if (!_envelope) {
        NSError *error;
        SSKProtoEnvelope *_Nullable envelope = [[SSKProtoEnvelope alloc] initWithSerializedData:self.envelopeData
                                                                                          error:&error];
        if (error || envelope == nil) {
            OWSFailDebug(@"Could not parse proto: %@", error);
        } else {
            _envelope = envelope;
        }
    }
    return _envelope;
}

- (BOOL)acceptNewIdentityKeyWithError:(NSError **)error
{
    OWSAssertIsOnMainThread();

    if (self.errorType != TSErrorMessageWrongTrustedIdentityKey) {
        OWSLogError(@"Refusing to accept identity key for anything but a Key error.");
        return YES;
    }

    NSData *_Nullable newKey = [self newIdentityKey:error];
    if (!newKey) {
        OWSFailDebug(@"Couldn't extract identity key to accept");
        return NO;
    }

    ServiceIdObjC *_Nullable serviceId = self.envelope.sourceAddress.serviceIdObjC;
    if (!serviceId) {
        OWSFailDebug(@"Couldn't extract ServiceId to accept");
        return YES;
    }

    DatabaseStorageWrite(SSKEnvironment.shared.databaseStorageRef, ^(SDSAnyWriteTransaction *tx) {
        [OWSIdentityManagerObjCBridge saveIdentityKey:newKey forServiceId:serviceId transaction:tx];
    });

    __block NSArray<TSInvalidIdentityKeyReceivingErrorMessage *> *_Nullable messagesToDecrypt;
    [SSKEnvironment.shared.databaseStorageRef readWithBlock:^(SDSAnyReadTransaction *tx) {
        messagesToDecrypt = [[self threadWithTx:tx] receivedMessagesForInvalidKey:newKey tx:tx];
    }];

    // Decrypt this and any old messages for the newly accepted key
    [self decryptWithMessagesToDecrypt:messagesToDecrypt];
    return YES;
}

- (nullable NSData *)newIdentityKey:(NSError **)error
{
    if (!self.envelope) {
        OWSLogError(@"Error message had no envelope data to extract key from");
        return nil;
    }
    if (!self.envelope.hasType) {
        OWSLogError(@"Error message envelope is missing type.");
        return nil;
    }
    if (self.envelope.unwrappedType != SSKProtoEnvelopeTypePrekeyBundle) {
        OWSLogError(@"Refusing to attempt key extraction from an envelope which isn't a prekey bundle");
        return nil;
    }

    NSData *pkwmData = self.envelope.content;
    if (!pkwmData) {
        OWSLogError(@"Ignoring acceptNewIdentityKey for empty message");
        return nil;
    }

    return [[self class] identityKeyFromEncodedPreKeySignalMessage:pkwmData error:error];
}

- (SignalServiceAddress *)theirSignalAddress
{
    OWSAssertDebug(self.envelope.sourceAddress != nil);

    return self.envelope.sourceAddress;
}

@end

NS_ASSUME_NONNULL_END
