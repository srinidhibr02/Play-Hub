import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/service/auth_service.dart';

class RatingsAndReviewScreen extends StatefulWidget {
  final String clubId;
  final double currentRating;
  final int totalRatings;

  const RatingsAndReviewScreen({
    super.key,
    required this.clubId,
    required this.currentRating,
    required this.totalRatings,
  });

  @override
  State<RatingsAndReviewScreen> createState() => _RatingsAndReviewScreenState();
}

class _RatingsAndReviewScreenState extends State<RatingsAndReviewScreen>
    with TickerProviderStateMixin {
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 0;
  bool _isSubmittingReview = false;

  Future<void> _submitReview() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please select a rating'),
            ],
          ),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final clubDoc = FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId);

      final reviewData = {
        'userEmail':
            AuthService().currentUserEmailId ??
            AuthService().currentUser!.phoneNumber ??
            'Anonymous',
        'rating': _userRating,
        'review': _reviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await clubDoc.collection('ratings_&_review').add(reviewData);

      // Calculate new average
      final reviewsSnapshot = await clubDoc
          .collection('ratings_&_review')
          .get();
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        for (var reviewDoc in reviewsSnapshot.docs) {
          final rating = reviewDoc.data()['rating'] as num? ?? 0;
          totalRating += rating.toDouble();
        }
        final averageRating = totalRating / reviewsSnapshot.docs.length;

        await clubDoc.update({
          'rating': double.parse(averageRating.toStringAsFixed(1)),
          'totalRatings': reviewsSnapshot.docs.length,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Review submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.teal.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        _reviewController.clear();
        setState(() => _userRating = 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to submit review'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 🟢 Teal AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            snap: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.transparent.withAlpha((255 * 0.1).toInt()),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 25,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade600,
                      Colors.teal.shade700,
                      Colors.teal.shade800,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Reviews & Ratings',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.totalRatings} reviews • ${widget.currentRating.toStringAsFixed(1)}⭐',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withAlpha((255 * 0.9).toInt()),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 📊 Rating Summary with REAL DATA
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.08).toInt()),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('ratings_&_review')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    );
                  }

                  final reviews =
                      snapshot.data?.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList() ??
                      [];

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Badge
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade400,
                              Colors.teal.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.shade300.withAlpha(
                                (255 * 0.5).toInt(),
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  reviews.isNotEmpty
                                      ? (reviews
                                                    .map(
                                                      (r) =>
                                                          (r['rating'] as num?)
                                                              ?.toDouble() ??
                                                          0,
                                                    )
                                                    .reduce((a, b) => a + b) /
                                                reviews.length)
                                            .toStringAsFixed(1)
                                      : widget.currentRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${reviews.length} reviews',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              _buildRatingBar(5, reviews),
                              _buildRatingBar(4, reviews),
                              _buildRatingBar(3, reviews),
                              _buildRatingBar(2, reviews),
                              _buildRatingBar(1, reviews),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ✍️ Write Review Form
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.06).toInt()),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: Colors.teal.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Share Your Review',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: List.generate(5, (index) {
                      final rating = 1 + index;
                      final isSelected = _userRating == rating;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _userRating = rating.toDouble()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      Colors.orangeAccent.shade200,
                                      Colors.orangeAccent.shade700,
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.grey.shade200,
                                      Colors.grey.shade300,
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.orangeAccent.shade400
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$rating',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your experience... (optional)',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.teal.shade400,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmittingReview ? null : _submitReview,
                      child: _isSubmittingReview
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Submitting...'),
                              ],
                            )
                          : const Text(
                              'Submit Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📝 Reviews List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('ratings_&_review')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    );
                  }

                  final reviews = snapshot.data?.docs ?? [];

                  if (reviews.isEmpty) {
                    return _buildNoReviewsYet();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final review =
                          reviews[index].data() as Map<String, dynamic>;
                      return _buildReviewCard(review);
                    },
                  );
                },
              );
            }, childCount: 1),
          ),
        ],
      ),
    );
  }

  // ✅ REAL DATA RATING BARS
  Widget _buildRatingBar(
    int starRating,
    List<Map<String, dynamic>> allReviews,
  ) {
    final starCount = allReviews.where((review) {
      final rating = (review['rating'] as num?)?.toDouble() ?? 0;
      return rating.round() == starRating;
    }).length;

    final percentage = allReviews.isEmpty
        ? 0
        : ((starCount / allReviews.length) * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              '$starRating ⭐',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade500),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReviewsYet() {
    return Container(
      margin: const EdgeInsets.all(60),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.reviews_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Be the first to share your experience!",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final userEmail = review['userEmail'] as String? ?? 'Anonymous';
    final reviewText = review['review'] as String? ?? '';
    final timestamp = review['timestamp'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final star = 1 + index;
                  return Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: star <= rating
                        ? Colors.amber.shade400
                        : Colors.grey.shade300,
                  );
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userEmail.split('@').first,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (timestamp != null)
                Text(
                  _formatTimeAgo(timestamp.toDate()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reviewText,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }
}
