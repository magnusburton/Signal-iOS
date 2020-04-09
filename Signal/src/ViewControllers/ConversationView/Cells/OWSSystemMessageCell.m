//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "OWSSystemMessageCell.h"
#import "ConversationViewItem.h"
#import "Signal-Swift.h"
#import "UIFont+OWS.h"
#import "UIView+OWS.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalServiceKit/OWSUnknownProtocolVersionMessage.h>
#import <SignalServiceKit/OWSVerificationStateChangeMessage.h>
#import <SignalServiceKit/TSCall.h>
#import <SignalServiceKit/TSErrorMessage.h>
#import <SignalServiceKit/TSInfoMessage.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SystemMessageActionBlock)(void);

@interface SystemMessageAction : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) SystemMessageActionBlock block;
@property (nonatomic) NSString *accessibilityIdentifier;

@end

#pragma mark -

@implementation SystemMessageAction

+ (SystemMessageAction *)actionWithTitle:(NSString *)title
                                   block:(SystemMessageActionBlock)block
                 accessibilityIdentifier:(NSString *)accessibilityIdentifier
{
    SystemMessageAction *action = [SystemMessageAction new];
    action.title = title;
    action.block = block;
    action.accessibilityIdentifier = accessibilityIdentifier;
    return action;
}

@end

#pragma mark -

@interface OWSSystemMessageCell () <UIGestureRecognizerDelegate>

@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIButton *button;
@property (nonatomic) UIStackView *contentStackView;
@property (nonatomic) UIView *cellBackgroundView;
@property (nonatomic) NSArray<NSLayoutConstraint *> *layoutConstraints;
@property (nonatomic, nullable) SystemMessageAction *action;
@property (nonatomic) MessageSelectionView *selectionView;
@property (nonatomic, readonly) UITapGestureRecognizer *contentViewTapGestureRecognizer;
@property (nonatomic) UIView *iconSpacer;
@property (nonatomic) UIView *buttonSpacer;

@end

#pragma mark -

@implementation OWSSystemMessageCell

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithFrame:CGRectZero];
}

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commontInit];
    }

    return self;
}

- (void)commontInit
{
    OWSAssertDebug(!self.iconView);

    self.layoutMargins = UIEdgeInsetsZero;
    self.contentView.layoutMargins = UIEdgeInsetsZero;
    self.layoutConstraints = @[];

    self.iconView = [UIImageView new];
    [self.iconView autoSetDimension:ALDimensionWidth toSize:self.iconSize];
    [self.iconView autoSetDimension:ALDimensionHeight toSize:self.iconSize];
    [self.iconView setContentHuggingHigh];

    self.selectionView = [MessageSelectionView new];
    _contentViewTapGestureRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleContentViewTapGesture:)];
    self.contentViewTapGestureRecognizer.delegate = self;
    [self.contentView addGestureRecognizer:self.contentViewTapGestureRecognizer];

    self.titleLabel = [UILabel new];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    self.button.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.button.layer.cornerRadius = 4.f;
    [self.button addTarget:self action:@selector(buttonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.button autoSetDimension:ALDimensionHeight toSize:self.buttonHeight];

    self.iconSpacer = [UIView spacerWithHeight:self.iconVSpacing];
    self.buttonSpacer = [UIView spacerWithHeight:self.buttonVSpacing];

    UIStackView *vStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconView,
        self.iconSpacer,
        self.titleLabel,
        self.buttonSpacer,
        self.button,
    ]];
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.alignment = UIStackViewAlignmentCenter;

    UIStackView *selectionViewWrapper =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.selectionView, [UIView hStretchingSpacer] ]];
    UIView *trailingCenteredPadding = [UIView hStretchingSpacer];
    UIStackView *contentStackView =
        [[UIStackView alloc] initWithArrangedSubviews:@[ selectionViewWrapper, vStackView, trailingCenteredPadding ]];

    // center the vstack with padding views.
    // It's tricky because we don't want the vStack to move when revealing the
    // selectionView.
    [trailingCenteredPadding autoMatchDimension:ALDimensionWidth
                                    toDimension:ALDimensionWidth
                                         ofView:selectionViewWrapper];

    contentStackView.axis = UILayoutConstraintAxisHorizontal;
    contentStackView.spacing = ConversationStyle.messageStackSpacing;
    contentStackView.layoutMarginsRelativeArrangement = YES;
    self.contentStackView = contentStackView;

    self.cellBackgroundView = [UIView new];
    self.cellBackgroundView.layer.cornerRadius = 5.f;
    [self.contentView addSubview:self.cellBackgroundView];

    [self.contentView addSubview:contentStackView];
    [contentStackView autoPinEdgesToSuperviewEdges];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    longPress.delegate = self;
    [self addGestureRecognizer:longPress];
}

- (CGFloat)buttonVSpacing
{
    return 7.f;
}

- (CGFloat)iconVSpacing
{
    return 9.f;
}

- (CGFloat)buttonHeight
{
    return 40.f;
}

- (CGFloat)buttonHPadding
{
    return 20.f;
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

- (void)loadForDisplay
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    self.cellBackgroundView.backgroundColor = [Theme backgroundColor];

    [self.button setBackgroundColor:Theme.conversationButtonBackgroundColor];
    [self.button setTitleColor:Theme.conversationButtonTextColor forState:UIControlStateNormal];

    TSInteraction *interaction = self.viewItem.interaction;

    self.action = [self actionForInteraction:interaction];

    UIImage *_Nullable icon = [self iconForInteraction:interaction];
    if (icon) {
        self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.iconView.tintColor = [self iconColorForInteraction:interaction];
        self.iconView.hidden = NO;
        self.iconSpacer.hidden = NO;
    } else {
        self.iconView.hidden = YES;
        self.iconSpacer.hidden = YES;
    }

    self.selectionView.hidden = !self.delegate.isShowingSelectionUI;

    self.titleLabel.textColor = [self textColor];
    [self applyTitleForInteraction:interaction label:self.titleLabel];
    CGSize titleSize = [self titleSize];

    if (self.action) {
        [self.button setTitle:self.action.title forState:UIControlStateNormal];
        UIFont *buttonFont = UIFont.ows_dynamicTypeSubheadlineFont.ows_semibold;
        self.button.titleLabel.font = buttonFont;
        self.button.accessibilityIdentifier = self.action.accessibilityIdentifier;
        self.button.hidden = NO;
        self.buttonSpacer.hidden = NO;
    } else {
        self.button.accessibilityIdentifier = nil;
        self.button.hidden = YES;
        self.buttonSpacer.hidden = YES;
    }
    CGSize buttonSize = [self.button sizeThatFits:CGSizeZero];

    [NSLayoutConstraint deactivateConstraints:self.layoutConstraints];

    self.contentStackView.layoutMargins = UIEdgeInsetsMake(self.topVMargin,
        self.conversationStyle.fullWidthGutterLeading,
        self.bottomVMargin,
        self.conversationStyle.fullWidthGutterLeading);

    self.layoutConstraints = @[
        [self.titleLabel autoSetDimension:ALDimensionWidth toSize:titleSize.width],
        [self.button autoSetDimension:ALDimensionWidth toSize:buttonSize.width + self.buttonHPadding * 2.f],

        [self.cellBackgroundView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.contentStackView],
        [self.cellBackgroundView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.contentStackView],
        // Text in vStackView might flow right up to the edges, so only use half the gutter.
        [self.cellBackgroundView autoPinEdgeToSuperviewEdge:ALEdgeLeading
                                                  withInset:self.conversationStyle.fullWidthGutterLeading * 0.5f],
        [self.cellBackgroundView autoPinEdgeToSuperviewEdge:ALEdgeTrailing
                                                  withInset:self.conversationStyle.fullWidthGutterTrailing * 0.5f],
    ];
}

- (void)setIsCellVisible:(BOOL)isCellVisible
{
    BOOL didChange = self.isCellVisible != isCellVisible;

    [super setIsCellVisible:isCellVisible];

    if (!didChange) {
        return;
    }

    if (isCellVisible) {
        self.selectionView.hidden = !self.delegate.isShowingSelectionUI;
    } else {
        self.selectionView.hidden = YES;
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];

    // cellBackgroundView is helpful to focus on the interaction while message actions are
    // presented, but we don't want it to obscure the "selected" background tint.
    self.cellBackgroundView.hidden = selected;

    self.selectionView.isSelected = selected;
}

- (void)handleContentViewTapGesture:(UITapGestureRecognizer *)sender
{
    OWSAssertDebug(self.delegate);
    if (self.delegate.isShowingSelectionUI) {
        if (self.isSelected) {
            [self.delegate conversationCell:self didDeselectViewItem:self.viewItem];
        } else {
            [self.delegate conversationCell:self didSelectViewItem:self.viewItem];
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.delegate.isShowingSelectionUI) {
        return self.contentViewTapGestureRecognizer == gestureRecognizer;
    } else {
        return YES;
    }
}

- (UIColor *)textColor
{
    return Theme.secondaryTextAndIconColor;
}

- (UIColor *)iconColorForInteraction:(TSInteraction *)interaction
{
    // "Phone", "Shield" and "Hourglass" icons have a lot of "ink" so they
    // are less dark for balance.
    return Theme.secondaryTextAndIconColor;
}

- (nullable UIImage *)iconForInteraction:(TSInteraction *)interaction
{
    UIImage *result = nil;

    if ([interaction isKindOfClass:[TSErrorMessage class]]) {
        switch (((TSErrorMessage *)interaction).errorType) {
            case TSErrorMessageNonBlockingIdentityChange:
            case TSErrorMessageWrongTrustedIdentityKey:
                result = [UIImage imageNamed:@"system_message_security"];
                break;
            case TSErrorMessageInvalidKeyException:
            case TSErrorMessageMissingKeyId:
            case TSErrorMessageNoSession:
            case TSErrorMessageInvalidMessage:
            case TSErrorMessageDuplicateMessage:
            case TSErrorMessageInvalidVersion:
            case TSErrorMessageUnknownContactBlockOffer:
            case TSErrorMessageGroupCreationFailed:
                return nil;
        }
    } else if ([interaction isKindOfClass:[TSInfoMessage class]]) {
        switch (((TSInfoMessage *)interaction).messageType) {
            case TSInfoMessageUserNotRegistered:
            case TSInfoMessageTypeSessionDidEnd:
            case TSInfoMessageTypeUnsupportedMessage:
            case TSInfoMessageAddToContactsOffer:
            case TSInfoMessageAddUserToProfileWhitelistOffer:
            case TSInfoMessageAddGroupToProfileWhitelistOffer:
                return nil;
            case TSInfoMessageTypeGroupUpdate:
            case TSInfoMessageTypeGroupQuit:
                return [Theme iconImage:ThemeIconGroupMessage];
            case TSInfoMessageUnknownProtocolVersion:
                OWSAssertDebug([interaction isKindOfClass:[OWSUnknownProtocolVersionMessage class]]);
                if ([interaction isKindOfClass:[OWSUnknownProtocolVersionMessage class]]) {
                    OWSUnknownProtocolVersionMessage *message = (OWSUnknownProtocolVersionMessage *)interaction;
                    result = [UIImage imageNamed:(message.isProtocolVersionUnknown ? @"message_status_failed"
                                                                                   : @"check-circle-outline-28")];
                }
                break;
            case TSInfoMessageTypeDisappearingMessagesUpdate: {
                BOOL areDisappearingMessagesEnabled = YES;
                if ([interaction isKindOfClass:[OWSDisappearingConfigurationUpdateInfoMessage class]]) {
                    areDisappearingMessagesEnabled
                        = ((OWSDisappearingConfigurationUpdateInfoMessage *)interaction).configurationIsEnabled;
                } else {
                    OWSFailDebug(@"unexpected interaction type: %@", interaction.class);
                }
                result = (areDisappearingMessagesEnabled ? [Theme iconImage:ThemeIconSettingsTimer]
                                                         : [Theme iconImage:ThemeIconSettingsTimerDisabled]);
                break;
            }
            case TSInfoMessageVerificationStateChange:
                OWSAssertDebug([interaction isKindOfClass:[OWSVerificationStateChangeMessage class]]);
                if ([interaction isKindOfClass:[OWSVerificationStateChangeMessage class]]) {
                    OWSVerificationStateChangeMessage *message = (OWSVerificationStateChangeMessage *)interaction;
                    BOOL isVerified = message.verificationState == OWSVerificationStateVerified;
                    if (!isVerified) {
                        return nil;
                    }
                }
                result = [UIImage imageNamed:@"check-circle-outline-28"];
                break;
            case TSInfoMessageUserJoinedSignal:
                result = [UIImage imageNamed:@"emoji-heart-filled-28"];
                break;
            case TSInfoMessageSyncedThread:
                result = [Theme iconImage:ThemeIconInfo];
                break;
        }
    } else if ([interaction isKindOfClass:[TSCall class]]) {
        result = [Theme iconImage:ThemeIconPhone];
    } else {
        OWSFailDebug(@"Unknown interaction type: %@", [interaction class]);
        return nil;
    }
    OWSAssertDebug(result);
    return result;
}

- (void)applyTitleForInteraction:(TSInteraction *)interaction
                           label:(UILabel *)label
{
    OWSAssertDebug(interaction);
    OWSAssertDebug(label);
    OWSAssertDebug(self.viewItem.systemMessageText.length > 0);

    NSMutableAttributedString *labelText =
        [[NSMutableAttributedString alloc] initWithString:self.viewItem.systemMessageText
                                               attributes:@{
                                                   NSFontAttributeName : UIFont.ows_dynamicTypeSubheadlineFont,
                                               }];

    if (self.shouldShowTimestamp) {
        NSString *timestampText = [DateUtil formatMessageTimestamp:interaction.timestamp];
        [labelText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        [labelText appendAttributedString:[[NSAttributedString alloc]
                                              initWithString:timestampText.localizedUppercaseString
                                                  attributes:@{
                                                      NSFontAttributeName : UIFont.ows_dynamicTypeCaption1Font,
                                                  }]];
    }

    label.attributedText = labelText;
}

- (CGFloat)topVMargin
{
    return 5.f;
}

- (CGFloat)bottomVMargin
{
    return 5.f;
}

- (CGFloat)hSpacing
{
    return 8.f;
}

- (CGFloat)iconSize
{
    return 20.f;
}

- (BOOL)shouldShowTimestamp
{
    return self.viewItem.interaction.interactionType == OWSInteractionType_Call;
}

- (CGSize)titleSize
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    CGFloat maxTitleWidth = (CGFloat)floor(self.conversationStyle.selectableCenteredContentWidth);
    return [self.titleLabel sizeThatFits:CGSizeMake(maxTitleWidth, CGFLOAT_MAX)];
}

- (CGSize)cellSize
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    TSInteraction *interaction = self.viewItem.interaction;

    CGSize result = CGSizeMake(self.conversationStyle.viewWidth, 0);

    UIImage *_Nullable icon = [self iconForInteraction:interaction];
    if (icon) {
        result.height += self.iconSize + self.iconVSpacing;
    }

    [self applyTitleForInteraction:interaction label:self.titleLabel];
    CGSize titleSize = [self titleSize];
    result.height += titleSize.height;

    SystemMessageAction *_Nullable action = [self actionForInteraction:interaction];
    if (action) {
        result.height += self.buttonHeight + self.buttonVSpacing;
    }

    result.height += self.topVMargin + self.bottomVMargin;

    return result;
}

#pragma mark - Actions

- (nullable SystemMessageAction *)actionForInteraction:(TSInteraction *)interaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(interaction);

    if ([interaction isKindOfClass:[TSErrorMessage class]]) {
        return [self actionForErrorMessage:(TSErrorMessage *)interaction];
    } else if ([interaction isKindOfClass:[TSInfoMessage class]]) {
        return [self actionForInfoMessage:(TSInfoMessage *)interaction];
    } else if ([interaction isKindOfClass:[TSCall class]]) {
        return [self actionForCall:(TSCall *)interaction];
    } else {
        OWSFailDebug(@"Tap for system messages of unknown type: %@", [interaction class]);
        return nil;
    }
}

- (nullable SystemMessageAction *)actionForErrorMessage:(TSErrorMessage *)message
{
    OWSAssertDebug(message);

    __weak OWSSystemMessageCell *weakSelf = self;
    switch (message.errorType) {
        case TSErrorMessageInvalidKeyException:
            return nil;
        case TSErrorMessageNonBlockingIdentityChange:
            return [SystemMessageAction
                        actionWithTitle:NSLocalizedString(@"SYSTEM_MESSAGE_ACTION_VERIFY_SAFETY_NUMBER",
                                            @"Label for button to verify a user's safety number.")
                                  block:^{
                                      [weakSelf.delegate
                                          tappedNonBlockingIdentityChangeForAddress:message.recipientAddress];
                                  }
                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"verify_safety_number")];
        case TSErrorMessageWrongTrustedIdentityKey:
            return [SystemMessageAction
                        actionWithTitle:NSLocalizedString(@"SYSTEM_MESSAGE_ACTION_VERIFY_SAFETY_NUMBER",
                                            @"Label for button to verify a user's safety number.")
                                  block:^{
                                      [weakSelf.delegate
                                          tappedInvalidIdentityKeyErrorMessage:(TSInvalidIdentityKeyErrorMessage *)
                                                                                   message];
                                  }
                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"verify_safety_number")];
        case TSErrorMessageMissingKeyId:
        case TSErrorMessageNoSession:
            return nil;
        case TSErrorMessageInvalidMessage:
            return [SystemMessageAction actionWithTitle:NSLocalizedString(@"FINGERPRINT_SHRED_KEYMATERIAL_BUTTON", @"")
                                                  block:^{
                                                      [weakSelf.delegate tappedCorruptedMessage:message];
                                                  }
                                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"reset_session")];
        case TSErrorMessageDuplicateMessage:
        case TSErrorMessageInvalidVersion:
            return nil;
        case TSErrorMessageUnknownContactBlockOffer:
            OWSFailDebug(@"TSErrorMessageUnknownContactBlockOffer");
            return nil;
        case TSErrorMessageGroupCreationFailed:
            return [SystemMessageAction actionWithTitle:CommonStrings.retryButton
                                                  block:^{
                                                      [weakSelf.delegate resendGroupUpdateForErrorMessage:message];
                                                  }
                                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"retry")];
    }

    OWSLogWarn(@"Unhandled tap for error message:%@", message);
    return nil;
}

- (nullable SystemMessageAction *)actionForInfoMessage:(TSInfoMessage *)infoMessage
{
    OWSAssertDebug(infoMessage);

    __weak OWSSystemMessageCell *weakSelf = self;
    switch (infoMessage.messageType) {
        case TSInfoMessageUserNotRegistered:
        case TSInfoMessageTypeSessionDidEnd:
            return nil;
        case TSInfoMessageTypeUnsupportedMessage:
            // Unused.
            return nil;
        case TSInfoMessageAddToContactsOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddToContactsOffer");
            return nil;
        case TSInfoMessageAddUserToProfileWhitelistOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddUserToProfileWhitelistOffer");
            return nil;
        case TSInfoMessageAddGroupToProfileWhitelistOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddGroupToProfileWhitelistOffer");
            return nil;
        case TSInfoMessageTypeGroupUpdate:
            return nil;
        case TSInfoMessageTypeGroupQuit:
            return nil;
        case TSInfoMessageUnknownProtocolVersion: {
            if (![infoMessage isKindOfClass:[OWSUnknownProtocolVersionMessage class]]) {
                OWSFailDebug(@"Unexpected message type.");
                return nil;
            }
            OWSUnknownProtocolVersionMessage *message = (OWSUnknownProtocolVersionMessage *)infoMessage;
            if (message.isProtocolVersionUnknown) {
                return [SystemMessageAction
                            actionWithTitle:NSLocalizedString(@"UNKNOWN_PROTOCOL_VERSION_UPGRADE_BUTTON",
                                                @"Label for button that lets users upgrade the app.")
                                      block:^{
                                          [weakSelf showUpgradeAppUI];
                                      }
                    accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"show_upgrade_app_ui")];
            }
            return nil;
        }
        case TSInfoMessageTypeDisappearingMessagesUpdate:
            if ([self.delegate conversationCellHasPendingMessageRequest:self]) {
                return nil;
            }
            return [SystemMessageAction
                        actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_TAP_TO_CHANGE",
                                            @"Label for button that opens conversation settings.")
                                  block:^{
                                      [weakSelf.delegate showConversationSettings];
                                  }
                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"show_conversation_settings")];
        case TSInfoMessageVerificationStateChange:
            return [SystemMessageAction
                        actionWithTitle:NSLocalizedString(@"SHOW_SAFETY_NUMBER_ACTION", @"Action sheet item")
                                  block:^{
                                      [weakSelf.delegate
                                          showFingerprintWithAddress:((OWSVerificationStateChangeMessage *)infoMessage)
                                                                         .recipientAddress];
                                  }
                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"show_safety_number")];
        case TSInfoMessageUserJoinedSignal:
            return nil;
        case TSInfoMessageSyncedThread:
            return nil;
    }

    OWSLogInfo(@"Unhandled tap for info message: %@", infoMessage);
    return nil;
}

- (nullable SystemMessageAction *)actionForCall:(TSCall *)call
{
    OWSAssertDebug(call);

    __weak OWSSystemMessageCell *weakSelf = self;
    switch (call.callType) {
        case RPRecentCallTypeIncoming:
        case RPRecentCallTypeIncomingMissed:
        case RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity:
        case RPRecentCallTypeIncomingDeclined:
            if ([self.delegate conversationCellHasPendingMessageRequest:self]) {
                return nil;
            }
            return
                [SystemMessageAction actionWithTitle:NSLocalizedString(@"CALLBACK_BUTTON_TITLE", @"notification action")
                                               block:^{
                                                   [weakSelf.delegate handleCallTap:call];
                                               }
                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"call_back")];
        case RPRecentCallTypeOutgoing:
        case RPRecentCallTypeOutgoingMissed:
            if ([self.delegate conversationCellHasPendingMessageRequest:self]) {
                return nil;
            }
            return [SystemMessageAction actionWithTitle:NSLocalizedString(@"CALL_AGAIN_BUTTON_TITLE",
                                                            @"Label for button that lets users call a contact again.")
                                                  block:^{
                                                      [weakSelf.delegate handleCallTap:call];
                                                  }
                                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"call_again")];
        case RPRecentCallTypeOutgoingIncomplete:
        case RPRecentCallTypeIncomingIncomplete:
            return nil;
    }
}

#pragma mark - Events

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)longPress
{
    OWSAssertDebug(self.delegate);

    __unused TSInteraction *interaction = self.viewItem.interaction;
    OWSAssertDebug(interaction);

    if (longPress.state == UIGestureRecognizerStateBegan) {
        [self.delegate conversationCell:self didLongpressSystemMessageViewItem:self.viewItem];
    }
}

- (void)buttonWasPressed:(id)sender
{
    if (self.delegate.isShowingSelectionUI) {
        // While in select mode, any actions should be superseded by the tap gesture.
        // TODO - this is kind of a hack. A better approach might be to disable the button
        // when delegate.isShowingSelectionUI changes, but that requires some additional plumbing.
        if (self.isSelected) {
            [self.delegate conversationCell:self didDeselectViewItem:self.viewItem];
        } else {
            [self.delegate conversationCell:self didSelectViewItem:self.viewItem];
        }
    } else if (!self.action.block) {
        OWSFailDebug(@"Missing action");
    } else {
        self.action.block();
    }
}

- (void)showUpgradeAppUI
{
    NSString *url = @"https://itunes.apple.com/us/app/signal-private-messenger/id874139669?mt=8";
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.action = nil;
    self.selectionView.alpha = 1.0;
    self.selected = NO;
}

@end

NS_ASSUME_NONNULL_END
