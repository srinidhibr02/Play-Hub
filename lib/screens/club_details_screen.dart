import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/screens/ratings_and_review_screen.dart';
import 'package:play_hub/service/auth_service.dart';

class ClubDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> club;

  const ClubDetailsScreen({super.key, required this.club});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  double _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

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
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      // ✅ Get club document reference
      final clubDoc = FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.club['id']); // Assuming you have clubId

      // ✅ Store review in subcollection
      final reviewData = {
        'userEmail': AuthService().currentUserEmailId,
        'rating': _userRating,
        'review': _reviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await clubDoc.collection('ratings_&_review').add(reviewData);

      // ✅ Calculate new average rating
      final reviewsSnapshot = await clubDoc
          .collection('ratings_&_review')
          .get();
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        int totalReviews = reviewsSnapshot.docs.length;

        for (var reviewDoc in reviewsSnapshot.docs) {
          final rating = reviewDoc.data()['rating'] as num? ?? 0;
          totalRating += rating.toDouble();
        }

        final averageRating = totalRating / totalReviews;

        // ✅ Update club rating & totalRatings
        await clubDoc.update({
          'rating': double.parse(averageRating.toStringAsFixed(1)),
          'totalRatings': totalReviews,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // ✅ Success feedback
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
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        _reviewController.clear();
        setState(() => _userRating = 0);
      }
    } catch (e) {
      debugPrint('❌ Review submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to submit review: ${e.toString()}'),
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
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(widget.club['images'] ?? []);
    final Map<String, dynamic> openingHours = widget.club['openingHours'] ?? {};
    final Map<String, dynamic> pricePerHour = widget.club['pricePerHour'] ?? {};
    final List<String> sports = List<String>.from(widget.club['sports'] ?? []);
    final double rating = (widget.club['rating'] ?? 0).toDouble();
    final int totalRatings = widget.club['totalRatings'] ?? 0;
    final String phone = widget.club['phoneNumber'] ?? 'N/A';
    final String address = widget.club['address'] ?? 'N/A';
    final String city = widget.club['city'] ?? 'N/A';
    final String name = widget.club['name'] ?? 'Club Name';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Carousel
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  images.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                        ),
                  // Image Counter
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black26],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club Header Info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 16,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$address, $city',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RatingsAndReviewScreen(
                                            clubId: widget.club['id'],
                                            currentRating: rating,
                                            totalRatings: totalRatings,
                                          ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.amber.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.shade300
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '$totalRatings reviews',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Contact Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.phone_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Contact',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.call_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sports & Pricing - Two Column Layout
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sports & Pricing',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.3,
                            ),
                        itemCount: sports.length,
                        itemBuilder: (context, index) {
                          final sport = sports[index];
                          final price = pricePerHour[sport] ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade50,
                                  Colors.teal.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.teal.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.shade100.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getSportIcon(sport),
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sport,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.currency_rupee_rounded,
                                          size: 14,
                                          color: Colors.teal.shade700,
                                        ),
                                        Text(
                                          '$price/hr',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Opening Hours - Full Width
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opening Hours',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: openingHours.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final day = openingHours.keys.elementAt(index);
                          final hours = openingHours[day];
                          final isToday = _isToday(day);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isToday
                                    ? Colors.green.shade300
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: isToday
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (isToday)
                                          Text(
                                            'Today',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? Colors.green.shade100
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    hours,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isToday
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Reviews Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Your Experience',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Rating Stars Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Rating',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(5, (index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _userRating = (index + 1).toDouble();
                                    });
                                  },
                                  child: AnimatedScale(
                                    scale: _userRating > index ? 1.3 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 44,
                                      color: _userRating > index
                                          ? Colors.amber.shade500
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            if (_userRating > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getRatingText(_userRating.toInt()),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Review Text Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Review',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reviewController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText:
                                  'Share your feedback about this club...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.teal.shade700,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmittingReview ? null : _submitReview,
                          icon: _isSubmittingReview
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSubmittingReview
                                ? 'Submitting...'
                                : 'Submit Review',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                            elevation: _isSubmittingReview ? 0 : 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return Icons.sports_soccer;
      case 'gym':
        return Icons.fitness_center;
      case 'cricket':
        return Icons.sports_cricket;
      case 'badminton':
        return Icons.sports_tennis;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      default:
        return Icons.sports_rounded;
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '😞 Poor - Needs improvement';
      case 2:
        return '😐 Fair - Could be better';
      case 3:
        return '😊 Good - Satisfied';
      case 4:
        return '😄 Very Good - Impressed';
      case 5:
        return '🤩 Excellent - Would recommend!';
      default:
        return '';
    }
  }

  bool _isToday(String day) {
    final now = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[now.weekday - 1] == day;
  }
}
