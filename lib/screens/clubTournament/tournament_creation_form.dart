import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TournamentCreationForm extends StatefulWidget {
  final String userEmail;
  final VoidCallback onTournamentCreated;

  const TournamentCreationForm({
    super.key,
    required this.userEmail,
    required this.onTournamentCreated,
  });

  @override
  State<TournamentCreationForm> createState() => _TournamentCreationFormState();
}

class _TournamentCreationFormState extends State<TournamentCreationForm> {
  final _firestore = FirebaseFirestore.instance;
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _organizerController;
  late TextEditingController _contactNumberController;
  late TextEditingController _imageUrlController;
  late TextEditingController _clubSearchController;

  String _selectedSport = 'Badminton';
  Map<String, dynamic>? _selectedClub;
  List<Map<String, dynamic>> _filteredClubs = [];
  bool _showClubSuggestions = false;

  // Step 2
  late TextEditingController _maxParticipantsController;
  late TextEditingController _prizePoolController;

  bool _includeSingles = false;
  bool _includeDoubles = false;
  Map<String, TextEditingController> _entryFeeControllers = {};

  // Prize Options
  String _prizeOption = 'both'; // 'trophy', 'prizePool', 'both'
  late TextEditingController _trophyDescController;

  // Step 3
  DateTime? _tournamentDate;
  TimeOfDay? _tournamentTime;
  DateTime? _registrationDeadline;
  TimeOfDay? _deadlineTime;

  // Tournament Format
  String _tournamentFormat = 'round_robin'; // 'round_robin', 'knockout'

  final List<String> _predefinedRules = [
    'Bring Aadhar Card',
    'Only under age 30',
    'Only above age 30',
    'Bring your own equipments',
    'Equipment provided by organizer',
    'Valid ID proof required',
    'Advance payment required',
    'Team registration only',
    'Individual registration only',
    'Must have previous tournament experience',
  ];

  Set<int> _selectedRulesIndices = {};
  late TextEditingController _customRuleController;
  List<String> _finalRules = [];

  final List<String> sports = [
    'Badminton',
    'Cricket',
    'Football',
    'Tennis',
    'Volleyball',
    'Kabaddi',
  ];

  final GlobalKey<FormState> _step1FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step2FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step3FormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _organizerController = TextEditingController();
    _contactNumberController = TextEditingController();
    _imageUrlController = TextEditingController();
    _clubSearchController = TextEditingController();
    _clubSearchController.addListener(_searchClubs);

    _maxParticipantsController = TextEditingController();
    _prizePoolController = TextEditingController();
    _trophyDescController = TextEditingController();

    _customRuleController = TextEditingController();
  }

  void _createEntryFeeController(String key) {
    if (!_entryFeeControllers.containsKey(key)) {
      _entryFeeControllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _organizerController.dispose();
    _contactNumberController.dispose();
    _imageUrlController.dispose();
    _clubSearchController.dispose();
    _maxParticipantsController.dispose();
    _prizePoolController.dispose();
    _trophyDescController.dispose();
    _customRuleController.dispose();

    for (var controller in _entryFeeControllers.values) {
      controller.dispose();
    }
    _entryFeeControllers.clear();

    super.dispose();
  }

  Future<void> _searchClubs() async {
    final query = _clubSearchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredClubs = [];
        _showClubSuggestions = false;
      });
      return;
    }

    try {
      final snapshot = await _firestore.collection('clubs').get();
      final List<Map<String, dynamic>> clubs = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final city = (data['city'] ?? '').toString().toLowerCase();

          if (name.contains(query) || city.contains(query)) {
            final clubData = Map<String, dynamic>.from(data);
            clubData['clubId'] = doc.id;
            clubs.add(clubData);
          }
        } catch (e) {
          debugPrint('Error processing club: $e');
        }
      }

      if (mounted) {
        setState(() {
          _filteredClubs = clubs;
          _showClubSuggestions = clubs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error searching clubs: $e');
    }
  }

  void _goToStep2() {
    if (!_step1FormKey.currentState!.validate()) {
      return;
    }

    if (_selectedClub == null) {
      _showError('Please select a club');
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _goToStep3() {
    if (!_step2FormKey.currentState!.validate()) {
      return;
    }

    if (!_includeSingles && !_includeDoubles) {
      _showError('Please select at least Singles or Doubles');
      return;
    }

    if (_prizeOption != 'trophy' && _prizePoolController.text.isEmpty) {
      _showError('Please enter prize pool amount');
      return;
    }

    setState(() => _currentStep = 2);
  }

  void _goBackToStep2() {
    setState(() => _currentStep = 1);
  }

  void _goBackToStep1() {
    setState(() => _currentStep = 0);
  }

  void _onTournamentTypeChanged() {
    setState(() {
      _entryFeeControllers.clear();

      if (_includeSingles) {
        _createEntryFeeController('male_singles');
        _createEntryFeeController('female_singles');
      }

      if (_includeDoubles) {
        _createEntryFeeController('male_doubles');
        _createEntryFeeController('female_doubles');
        _createEntryFeeController('mixed_doubles');
      }
    });
  }

  void _addRuleFromPredefined(int index) {
    setState(() {
      if (_selectedRulesIndices.contains(index)) {
        _selectedRulesIndices.remove(index);
      } else {
        _selectedRulesIndices.add(index);
      }
      _updateFinalRules();
    });
  }

  void _addCustomRule() {
    if (_customRuleController.text.trim().isEmpty) {
      _showError('Please enter a rule');
      return;
    }

    setState(() {
      _finalRules.add(_customRuleController.text.trim());
      _customRuleController.clear();
    });
  }

  void _removeRule(int index) {
    setState(() {
      _finalRules.removeAt(index);
    });
  }

  void _updateFinalRules() {
    _finalRules.clear();
    for (int i = 0; i < _predefinedRules.length; i++) {
      if (_selectedRulesIndices.contains(i)) {
        _finalRules.add(_predefinedRules[i]);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createTournament() async {
    if (!_step3FormKey.currentState!.validate()) {
      return;
    }

    if (_tournamentDate == null || _tournamentTime == null) {
      _showError('Please select tournament date and time');
      return;
    }

    if (_registrationDeadline == null || _deadlineTime == null) {
      _showError('Please select registration deadline and time');
      return;
    }

    if (_finalRules.isEmpty) {
      _showError('Please select at least one rule');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine date and time
      final tournamentDateTime = DateTime(
        _tournamentDate!.year,
        _tournamentDate!.month,
        _tournamentDate!.day,
        _tournamentTime!.hour,
        _tournamentTime!.minute,
      );

      final deadlineDateTime = DateTime(
        _registrationDeadline!.year,
        _registrationDeadline!.month,
        _registrationDeadline!.day,
        _deadlineTime!.hour,
        _deadlineTime!.minute,
      );

      // Build entry fees
      final Map<String, dynamic> entryFees = {};

      if (_includeSingles) {
        entryFees['male'] ??= {};
        entryFees['male']['singles'] = int.parse(
          _entryFeeControllers['male_singles']?.text ?? '0',
        );

        entryFees['female'] ??= {};
        entryFees['female']['singles'] = int.parse(
          _entryFeeControllers['female_singles']?.text ?? '0',
        );
      }

      if (_includeDoubles) {
        entryFees['male'] ??= {};
        entryFees['male']['doubles'] = int.parse(
          _entryFeeControllers['male_doubles']?.text ?? '0',
        );

        entryFees['female'] ??= {};
        entryFees['female']['doubles'] = int.parse(
          _entryFeeControllers['female_doubles']?.text ?? '0',
        );

        entryFees['mixed-doubles'] = int.parse(
          _entryFeeControllers['mixed_doubles']?.text ?? '0',
        );
      }

      // Build prize details
      final Map<String, dynamic> prizeDetails = {};
      if (_prizeOption == 'trophy' || _prizeOption == 'both') {
        prizeDetails['hasTrophy'] = true;
        prizeDetails['trophyDescription'] = _trophyDescController.text.trim();
      }
      if (_prizeOption == 'prizePool' || _prizeOption == 'both') {
        prizeDetails['hasPrizePool'] = true;
        prizeDetails['prizePoolAmount'] = double.parse(
          _prizePoolController.text,
        );
      }

      final tournamentData = {
        'clubId': _selectedClub!['clubId'],
        'clubName': _selectedClub!['name'],
        'name': _nameController.text,
        'sport': _selectedSport,
        'description': _descriptionController.text,
        'organizer': _organizerController.text,
        'contactNumber': _contactNumberController.text,
        'imageUrl': _imageUrlController.text,
        'maxParticipants': int.parse(_maxParticipantsController.text),
        'currentParticipants': 0,
        'prizeDetails': prizeDetails,
        'entryFee': entryFees,
        'tournamentType': _buildTournamentTypeString(),
        'tournamentFormat': _tournamentFormat,
        'date': Timestamp.fromDate(tournamentDateTime),
        'registrationDeadline': Timestamp.fromDate(deadlineDateTime),
        'rules': _finalRules,
        'status': 'open',
        'participants': [],
        'createdAt': Timestamp.now(),
        'createdBy': widget.userEmail,
      };

      final docRef = _firestore.collection('tournaments').doc();
      await docRef.set(tournamentData);

      await _firestore.collection('users').doc(widget.userEmail).update({
        'hostedTournaments': FieldValue.arrayUnion([docRef.id]),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onTournamentCreated();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error: $e');
      }
    }
  }

  String _buildTournamentTypeString() {
    if (_includeSingles && _includeDoubles) {
      return 'Singles & Doubles';
    } else if (_includeSingles) {
      return 'Singles Only';
    } else {
      return 'Doubles Only';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildProgressBar(),
                  const SizedBox(height: 32),
                  if (_currentStep == 0) ...[
                    Form(key: _step1FormKey, child: _buildStep1Content()),
                  ] else if (_currentStep == 1) ...[
                    Form(key: _step2FormKey, child: _buildStep2Content()),
                  ] else ...[
                    Form(key: _step3FormKey, child: _buildStep3Content()),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStep == 0
                    ? '🎯 Create Tournament'
                    : _currentStep == 1
                    ? '⚙️ Configure Details'
                    : '📋 Set Rules & Dates',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentStep == 0
                    ? 'Add basic tournament information'
                    : _currentStep == 1
                    ? 'Define format and fees'
                    : 'Finalize tournament details',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.grey.shade700,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '${(_currentStep + 1).toString()}/3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.teal.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              Color.lerp(
                Colors.teal.shade600,
                Colors.green.shade600,
                (_currentStep + 1) / 3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Content() {
    return Column(
      children: [
        _buildInfoCard(
          'Tournament Name',
          'e.g., "City Level Badminton Championship"',
          Icons.emoji_events_rounded,
          _nameController,
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          'Description',
          'Describe tournament goals and details',
          Icons.description_rounded,
          _descriptionController,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          'Organizer Name',
          'e.g., "Sports Association"',
          Icons.business_rounded,
          _organizerController,
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          'Contact Number',
          '+91 XXXXXXXXXX',
          Icons.phone_rounded,
          _contactNumberController,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          'Image URL',
          'Link to tournament poster/image',
          Icons.image_rounded,
          _imageUrlController,
        ),
        const SizedBox(height: 20),
        _buildSportSelector(),
        const SizedBox(height: 20),
        _buildClubSelector(),
        const SizedBox(height: 32),
        _buildNavigation(onNext: _goToStep2, isBack: false),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      children: [
        _buildTournamentTypeCard(),
        const SizedBox(height: 24),
        _buildInfoCard(
          'Max Participants',
          'e.g., 32',
          Icons.people_rounded,
          _maxParticipantsController,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildPrizeOptionsCard(),
        const SizedBox(height: 24),
        if (_includeSingles || _includeDoubles) ...[
          _buildEntryFeesCard(),
          const SizedBox(height: 24),
        ],
        _buildNavigation(
          onBack: _goBackToStep1,
          onNext: _goToStep3,
          isBack: true,
        ),
      ],
    );
  }

  Widget _buildStep3Content() {
    return Column(
      children: [
        _buildTournamentFormatCard(),
        const SizedBox(height: 24),
        _buildDateTimePickerCard(),
        const SizedBox(height: 24),
        _buildRulesCard(),
        const SizedBox(height: 32),
        _buildNavigation(
          onBack: _goBackToStep2,
          onSubmit: _createTournament,
          isBack: true,
          isSubmit: true,
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.teal.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_rounded, color: Colors.orange.shade600),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sport Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButton<String>(
            value: _selectedSport,
            items: sports.map((sport) {
              return DropdownMenuItem(value: sport, child: Text(sport));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedSport = value!);
            },
            isExpanded: true,
            underline: const SizedBox(),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClubSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: Colors.blue.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Venue (Club)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clubSearchController,
          decoration: InputDecoration(
            hintText: 'Search and select club',
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            suffixIcon: _selectedClub != null
                ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600)
                : null,
          ),
        ),
        if (_showClubSuggestions && _filteredClubs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filteredClubs.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final club = _filteredClubs[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedClub = club;
                      _clubSearchController.text = club['name'] ?? '';
                      _showClubSuggestions = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.blue.shade50,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                club['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                club['city'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_selectedClub != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClub!['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          'Selected venue',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedClub = null;
                        _clubSearchController.clear();
                      });
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTournamentTypeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.category_rounded,
                color: Colors.purple.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tournament Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border.all(color: Colors.purple.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCheckboxTile(
                'Singles',
                'Male & Female Singles',
                _includeSingles,
                (value) {
                  setState(() {
                    _includeSingles = value ?? false;
                    _onTournamentTypeChanged();
                  });
                },
              ),
              Divider(color: Colors.purple.shade200, height: 20),
              _buildCheckboxTile(
                'Doubles',
                'Male, Female & Mixed Doubles',
                _includeDoubles,
                (value) {
                  setState(() {
                    _includeDoubles = value ?? false;
                    _onTournamentTypeChanged();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile(
    String title,
    String subtitle,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.purple.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeOptionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: Colors.amber.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Prize Options',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildRadioTile(
                'Trophy Only',
                'Award winning team with trophy',
                'trophy',
                _prizeOption,
                (value) {
                  setState(() => _prizeOption = value!);
                },
              ),
              const SizedBox(height: 12),
              _buildRadioTile(
                'Prize Pool Only',
                'Distribute cash prize pool to winners',
                'prizePool',
                _prizeOption,
                (value) {
                  setState(() => _prizeOption = value!);
                },
              ),
              const SizedBox(height: 12),
              _buildRadioTile(
                'Trophy & Prize Pool',
                'Award both trophy and cash prizes',
                'both',
                _prizeOption,
                (value) {
                  setState(() => _prizeOption = value!);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_prizeOption != 'trophy') ...[
          _buildInfoCard(
            'Prize Pool Amount',
            'Total prize money in ₹',
            Icons.attach_money_rounded,
            _prizePoolController,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 16),
        ],
        if (_prizeOption == 'trophy' || _prizeOption == 'both') ...[
          _buildInfoCard(
            'Trophy Description',
            'e.g., "Winners Trophy for Badminton Champions"',
            Icons.emoji_events_rounded,
            _trophyDescController,
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildRadioTile(
    String title,
    String subtitle,
    String value,
    String groupValue,
    Function(String?) onChanged,
  ) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: Colors.amber.shade600,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntryFeesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_offer_rounded,
                color: Colors.green.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Entry Fees',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_includeSingles) ...[
          _buildEntryFeeSection('Singles', Colors.blue, [
            ('Male Singles', 'male_singles', '₹ 350'),
            ('Female Singles', 'female_singles', '₹ 200'),
          ]),
          const SizedBox(height: 12),
        ],
        if (_includeDoubles) ...[
          _buildEntryFeeSection('Doubles', Colors.green, [
            ('Male Doubles', 'male_doubles', '₹ 500'),
            ('Female Doubles', 'female_doubles', '₹ 350'),
            ('Mixed Doubles', 'mixed_doubles', '₹ 500'),
          ]),
        ],
      ],
    );
  }

  Widget _buildEntryFeeSection(
    String title,
    Color color,
    List<(String, String, String)> fees,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          ...fees.map((fee) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      fee.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _entryFeeControllers[fee.$2],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: fee.$3,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTournamentFormatCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.schema_rounded,
                color: Colors.indigo.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tournament Format',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            border: Border.all(color: Colors.indigo.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildRadioTile(
                'Round Robin',
                'Every team plays against every other team',
                'round_robin',
                _tournamentFormat,
                (value) {
                  setState(() => _tournamentFormat = value!);
                },
              ),
              const SizedBox(height: 12),
              _buildRadioTile(
                'Knockout',
                'Elimination format - loser is out',
                'knockout',
                _tournamentFormat,
                (value) {
                  setState(() => _tournamentFormat = value!);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePickerCard() {
    return Column(
      children: [
        _buildDateTimeField(
          'Tournament Date & Time',
          _tournamentDate,
          _tournamentTime,
          (date, time) {
            setState(() {
              _tournamentDate = date;
              _tournamentTime = time;
            });
          },
          Icons.calendar_month_rounded,
        ),
        const SizedBox(height: 20),
        _buildDateTimeField(
          'Registration Deadline',
          _registrationDeadline,
          _deadlineTime,
          (date, time) {
            setState(() {
              _registrationDeadline = date;
              _deadlineTime = time;
            });
          },
          Icons.schedule_rounded,
        ),
      ],
    );
  }

  Widget _buildDateTimeField(
    String label,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    Function(DateTime?, TimeOfDay?) onDateTimeSelected,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.red.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Date Picker
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.red.shade600,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    onDateTimeSelected(picked, selectedTime);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate != null
                              ? DateFormat('MMM d, yyyy').format(selectedDate)
                              : 'Select date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selectedDate != null
                                ? Colors.black87
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Time Picker
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.red.shade600,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    onDateTimeSelected(selectedDate, picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedTime != null
                              ? selectedTime.format(context)
                              : 'Select time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selectedTime != null
                                ? Colors.black87
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.rule_rounded,
                color: Colors.deepPurple.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tournament Rules',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            border: Border.all(color: Colors.deepPurple.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              _predefinedRules.length,
              (index) => FilterChip(
                label: Text(_predefinedRules[index]),
                selected: _selectedRulesIndices.contains(index),
                onSelected: (_) => _addRuleFromPredefined(index),
                backgroundColor: Colors.white,
                selectedColor: Colors.deepPurple.shade100,
                side: BorderSide(
                  color: _selectedRulesIndices.contains(index)
                      ? Colors.deepPurple.shade600
                      : Colors.deepPurple.shade300,
                ),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _selectedRulesIndices.contains(index)
                      ? Colors.deepPurple.shade700
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customRuleController,
                decoration: InputDecoration(
                  hintText: 'Add custom rule',
                  prefixIcon: Icon(
                    Icons.add_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade600,
                    Colors.deepPurple.shade500,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addCustomRule,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_finalRules.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Rules (${_finalRules.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(
                  _finalRules.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _finalRules[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeRule(index),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigation({
    VoidCallback? onBack,
    VoidCallback? onNext,
    VoidCallback? onSubmit,
    bool isBack = false,
    bool isSubmit = false,
  }) {
    if (isSubmit) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade500],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : onSubmit,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.add_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _isLoading ? 'Creating...' : 'Create',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (isBack) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Next',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          label: const Text(
            'Next',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
  }
}
