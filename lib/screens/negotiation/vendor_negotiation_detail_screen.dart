import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/negotiation_detail_provider.dart';
import '../../services/negotiation_service.dart';
import '../../services/backend_service.dart';

class VendorNegotiationDetailScreen extends ConsumerStatefulWidget {
  final String negotiationId;
  final bool readOnly;

  const VendorNegotiationDetailScreen({
    super.key,
    required this.negotiationId,
    this.readOnly = false,
  });

  @override
  ConsumerState<VendorNegotiationDetailScreen> createState() =>
      _VendorNegotiationDetailScreenState();
}

class _VendorNegotiationDetailScreenState
    extends ConsumerState<VendorNegotiationDetailScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _counterAmountController =
      TextEditingController();
  final TextEditingController _counterNoteController = TextEditingController();

  bool _isSubmitting = false;
  bool _showCounterSheet = false;
  bool _expandedRequirement = false;
  double _minPrice = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchMinPrice();
  }

  Future<void> _fetchMinPrice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['vendorProfile'] != null) {
        setState(() {
          _minPrice = (data['vendorProfile']['minPrice'] ?? 0.0).toDouble();
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _counterAmountController.dispose();
    _counterNoteController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent +
            200, // pad to guarantee bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submitCounterOffer(
    NegotiationDetail detail,
    String amountText,
  ) async {
    final amount = double.tryParse(amountText);
    if (amount == null) return;

    // Use the backend-computed floorPrice from the negotiation doc.
    // This is already calculated with the correct guest count and category
    // by the pricing calculator — no manual re-multiplication needed.
    final double floorPrice = detail.floorPrice > 0
        ? detail.floorPrice
        : _minPrice; // fallback to vendor's base min price

    if (amount < floorPrice) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Counter offer cannot be less than your minimum price of PKR ${floorPrice.toStringAsFixed(0)}",
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(negotiationServiceProvider)
          .submitCounterOffer(
            widget.negotiationId,
            amount,
            _counterNoteController.text.trim(),
            firestoreNegotiationId: widget.negotiationId,
          );
      setState(() {
        _showCounterSheet = false;
      });
      _counterAmountController.clear();
      _counterNoteController.clear();
      // Auto triggers cloud function to agent on DB change
    } catch (e) {
      if (mounted) {
        final errorMsg = e is BackendException
            ? e.message
            : tr('error_try_again');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showRejectConfirmSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('confirm_reject'),
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('reject_warning'),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldenBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  tr('go_back'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isSubmitting = true);
                  try {
                    await ref
                        .read(negotiationServiceProvider)
                        .rejectNegotiation(
                          widget.negotiationId,
                          firestoreNegotiationId: widget.negotiationId,
                        );
                    if (mounted) context.pop();
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('error_try_again'))),
                      );
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                child: Text(
                  tr('yes_reject'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAcceptConfirmSheet(NegotiationDetail detail) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                'confirm_accept',
                args: [detail.currentOffer.toStringAsFixed(0)],
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr('back'),
                      style: GoogleFonts.inter(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.mossGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isSubmitting = true);
                      try {
                        await ref
                            .read(negotiationServiceProvider)
                            .acceptOffer(
                              widget.negotiationId,
                              detail.eventId,
                              detail.vendorId,
                              detail.currentOffer,
                              firestoreNegotiationId: widget.negotiationId,
                            );
                        if (mounted) {
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) context.pop();
                          });
                        }
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('error_try_again'))),
                          );
                      } finally {
                        if (mounted) setState(() => _isSubmitting = false);
                      }
                    },
                    child: Text(
                      tr('yes_accept'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NegotiationDetail detail) {
    final dateStr = DateFormat('dd MMM yyyy').format(detail.eventDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(detail.eventType),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${tr('date')}: $dateStr',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${tr('city')}: ${tr(detail.city)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.people, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                tr('guests', args: [detail.guestCount.toString()]),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                setState(() => _expandedRequirement = !_expandedRequirement),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr('requirement')}:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.requirement,
                  maxLines: _expandedRequirement ? null : 2,
                  overflow: _expandedRequirement
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _effectiveStatus(
    NegotiationDetail detail,
    List<NegotiationMessage> messages,
  ) {
    // Firestore doc status is the authoritative source — the backend (agent or
    // vendor-reply handler) always writes the terminal status to the doc first.
    // Checking it first prevents the accept/counter panel from showing after the
    // agent has already closed the deal on the customer's behalf.
    if (detail.status == 'deal') return 'deal';
    if (detail.status == 'no_deal') return 'no_deal';
    if (detail.status == 'expired') return 'expired';

    // Fallback: derive from messages in case the Firestore doc update arrives
    // slightly after the messages subcollection update (eventual consistency).
    if (messages.any((message) => message.messageType == 'accept')) {
      return 'deal';
    }
    if (messages.any((message) => message.messageType == 'reject')) {
      return 'no_deal';
    }
    return detail.status;
  }

  Widget _buildConversationLog(NegotiationDetail detail) {
    final messagesAsync = ref.watch(
      negotiationMessagesProvider(widget.negotiationId),
    );

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading messages: $e')),
      data: (messages) {
        final effectiveStatus = _effectiveStatus(detail, messages);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 80,
            left: 16,
            right: 16,
          ),
          itemCount: messages.length + 1, // +1 for typing indicator
          itemBuilder: (context, index) {
            if (index == messages.length) {
              if (!detail.isVendorTurn &&
                  effectiveStatus != 'deal' &&
                  effectiveStatus != 'no_deal' &&
                  effectiveStatus != 'expired') {
                return _buildAgentTypingIndicator();
              }
              return const SizedBox.shrink();
            }

            final msg = messages[index];
            final isAgent = msg.sender == 'agent';

            if (msg.messageType == 'accept') {
              return _buildDealBanner(
                msg,
                detail.finalPrice ?? msg.offerAmount,
              );
            }
            if (msg.messageType == 'reject') {
              return _buildRejectBanner();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: isAgent
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAgent) ...[
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: AppColors.goldenBrown,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isAgent ? tr('ai_agent') : tr('you'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAgent
                              ? AppColors.goldenBrown
                              : AppColors.mossGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isAgent ? Colors.white : null,
                      gradient: isAgent
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.mossGreen, Color(0xFF384A3B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isAgent
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                        bottomRight: isAgent
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                      ),
                      border: isAgent
                          ? Border.all(color: Colors.grey.shade200)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: isAgent
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        if (msg.content.isNotEmpty)
                          Text(
                            msg.content,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: isAgent ? Colors.black87 : Colors.white,
                              height: 1.3,
                            ),
                          ),
                        if ((msg.messageType == 'offer' ||
                                msg.messageType == 'counter') &&
                            msg.offerAmount != null)
                          Padding(
                            padding: EdgeInsets.only(
                              top: msg.content.isNotEmpty ? 12.0 : 0.0,
                            ),
                            child: Text(
                              'PKR ${msg.offerAmount!.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isAgent
                                    ? AppColors.goldenBrown
                                    : Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isAgent ? 4.0 : 0.0,
                      right: isAgent ? 0.0 : 4.0,
                    ),
                    child: Text(
                      DateFormat('hh:mm a').format(msg.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgentTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 12,
                color: AppColors.goldenBrown,
              ),
              const SizedBox(width: 4),
              Text(
                tr('ai_agent'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldenBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 4),
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 4),
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('agent_responding'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.goldenBrown,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _acceptedOfferAmount(
    NegotiationDetail detail,
    List<NegotiationMessage> messages,
  ) {
    final acceptedMessages = messages
        .where((message) => message.messageType == 'accept')
        .toList();
    if (acceptedMessages.isNotEmpty) {
      return acceptedMessages.last.offerAmount ?? detail.finalPrice;
    }
    return detail.finalPrice;
  }

  Widget _buildDealBanner(NegotiationMessage msg, double? finalPrice) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mossGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mossGreen),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.mossGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                tr('deal_confirmed'),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mossGreen,
                ),
              ),
            ],
          ),
          if (finalPrice != null) ...[
            const SizedBox(height: 12),
            Text(
              'PKR ${finalPrice.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.mossGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(
            tr('negotiation_ended'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePanel(NegotiationDetail detail) {
    final messagesAsync = ref.watch(
      negotiationMessagesProvider(widget.negotiationId),
    );

    return messagesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (messages) {
        final effectiveStatus = _effectiveStatus(detail, messages);

        if (widget.readOnly ||
            effectiveStatus == 'deal' ||
            effectiveStatus == 'no_deal' ||
            effectiveStatus == 'expired') {
          String statusKey = '';
          Color statusColor = Colors.grey;
          String? extraText;

          if (effectiveStatus == 'deal') {
            statusKey = 'deal_at';
            statusColor = AppColors.mossGreen;
            extraText =
                (_acceptedOfferAmount(detail, messages)?.toStringAsFixed(0) ??
                '');
          } else if (effectiveStatus == 'expired') {
            statusKey = 'request_expired';
            statusColor = AppColors.goldenBrown;
          } else {
            statusKey = 'negotiation_closed';
          }

          return Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  extraText != null
                      ? tr(statusKey, args: [extraText])
                      : tr(statusKey),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          );
        }

        if (!detail.isVendorTurn) {
          return Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 4),
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 4),
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.goldenBrown,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('agent_responding'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldenBrown,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mossGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _showAcceptConfirmSheet(detail),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('accept'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'PKR ${detail.currentOffer.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldenBrown,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _showCounterSheet = true;
                                });
                              },
                        child: Text(
                          tr('counter_offer'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : _showRejectConfirmSheet,
                        child: Text(
                          tr('reject'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCounterOfferSheet(NegotiationDetail detail) {
    if (!_showCounterSheet) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showCounterSheet = false),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: GestureDetector(
            onTap: () {}, // consume taps inside sheet
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.4,
              maxChildSize: 0.8,
              builder: (_, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    controller: controller,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('enter_your_price'),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showCounterSheet = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _counterAmountController,
                        builder: (context, value, child) {
                          final amount = double.tryParse(value.text);
                          final isInvalid =
                              value.text.isNotEmpty && amount == null;
                          // Use backend floorPrice if available, else _minPrice
                          final double effectiveFloor = detail.floorPrice > 0
                              ? detail.floorPrice
                              : _minPrice;
                          final isBelowMin =
                              amount != null && amount < effectiveFloor;
                          final canSubmit =
                              amount != null && amount >= effectiveFloor;

                          String? errorText;
                          if (isInvalid) errorText = tr('invalid_amount');
                          if (isBelowMin) errorText = tr('below_minimum');

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _counterAmountController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  prefixText: 'PKR ',
                                  prefixStyle: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.goldenBrown,
                                      width: 2,
                                    ),
                                  ),
                                  errorText: errorText,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                tr('add_note_optional'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _counterNoteController,
                                maxLength: 80,
                                style: GoogleFonts.inter(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: tr('note_hint'),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.goldenBrown,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                  ),
                                  onPressed: (!canSubmit || _isSubmitting)
                                      ? null
                                      : () => _submitCounterOffer(
                                          detail,
                                          value.text,
                                        ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          tr('send_counter'),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      negotiationDetailProvider(widget.negotiationId),
    );

    return PopScope(
      canPop: !_showCounterSheet,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showCounterSheet) {
          setState(() {
            _showCounterSheet = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          title: Text(
            tr('active_negotiations'),
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (detail) {
            return Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(detail),
                    Expanded(child: _buildConversationLog(detail)),
                    _buildResponsePanel(detail),
                  ],
                ),
                _buildCounterOfferSheet(detail),
              ],
            );
          },
        ),
      ),
    );
  }
}
