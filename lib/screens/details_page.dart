import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/draft_model.dart';
import '../services/draft_service.dart';
import '../providers/auth_provider.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({Key? key}) : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late DraftService _draftService;
  List<DraftModel> _drafts = [];
  List<dynamic> _committedEntries = [];
  bool _isLoadingEntries = false;
  String? _formId;
  String? _activityType;
  String? _formTitle;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _drafts = [];
    _committedEntries = [];
    _isLoadingEntries = false;
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Initialize TabController with a default length
    _tabController = TabController(
      length:
          2, // Default length; will update in didChangeDependencies if needed
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final newActivityType = args?['activity_type']?.toString() ?? 'Baseline';
    _formId = args?['form_id']?.toString();
    _formTitle = args?['form_title']?.toString() ?? 'Untitled';

    // Only update TabController length if activityType has changed
    if (_activityType != newActivityType) {
      _activityType = newActivityType;
      final newLength = _activityType == "Follow-up" ? 3 : 2;
      _tabController?.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
      );
    }

    _draftService = Provider.of<DraftService>(context, listen: false);

    _loadDrafts();
    _loadEntries();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadDrafts() {
    if (_formId != null &&
        _activityType != null) {
      setState(() {
        _drafts =
            _draftService.getDraftsByStatus(_formId!, _activityType!, 'draft');
      });
    }
  }

  Future<void> _loadEntries() async {
    if (_formId == null || _activityType == null) return;
    setState(() => _isLoadingEntries = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final regionId = auth.regionId ?? '1';
      debugPrint(
          'Loading entries for formId: $_formId, : $regionId, activityType: $_activityType');
      if (_activityType == "Baseline") {
        _committedEntries = await auth.apiService
            .fetchCommittedBaselineEntries(regionId, _formId!);
      } else {
        _committedEntries =
            await auth.apiService.fetchFollowUpEntries(regionId, _formId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entries: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingEntries = false);
    }
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraftTile(DraftModel draft) {
    final formattedDate =
        DateFormat('MMM d, yyyy h:mm a').format(draft.timestamp);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          draft.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          'Created: $formattedDate\nStatus: ${draft.status}',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/form_page',
                  arguments: {
                    'form_id': draft.formId,
                    'form_title': draft.title,
                    'activity_type': _activityType,
                    'draft': draft,
                  },
                ).then((_) {
                  _loadDrafts();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Delete Draft',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to delete this draft?',
                      style: GoogleFonts.poppins(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_formId != null && _activityType != null) {
                            _draftService.deleteDraft(
                                draft.formId, _activityType!, draft.timestamp);
                            Navigator.pop(context);
                            _loadDrafts();
                          }
                        },
                        child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(color: Colors.redAccent),
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
    );
  }

  Widget _buildCommittedTile(Map<String, dynamic> entry) {
    final title = entry['title']?.toString() ?? "N/A";
    final subTitle = entry['sub_title']?.toString() ?? "N/A";
    final parish = entry['parish']?.toString() ?? "N/A";
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          '$subTitle\n$parish',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: _activityType == "Follow-up"
            ? const Icon(Icons.edit, color: Colors.blueAccent)
            : null,
        onTap: _activityType == "Follow-up"
            ? () {
                Navigator.pushNamed(
                  context,
                  '/form_page',
                  arguments: {
                    'form_id': _formId,
                    'form_title': title,
                    'activity_type': _activityType,
                    'follow_up_data': entry,
                  },
                ).then((_) {
                  _loadEntries();
                });
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formTitle ?? 'Form Details',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: _activityType == "Follow-up"
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                    labelColor: const Color.fromARGB(255, 87, 92, 100),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    tabs: const [
                      Tab(text: 'NEW'),
                      Tab(text: 'DRAFTS'),
                      Tab(text: 'COMMITTED'),
                    ],
                  ),
                ),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    tabs: const [
                      Tab(text: 'DRAFTS'),
                      Tab(text: 'COMMITTED'),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async {
          _loadDrafts();
          await _loadEntries();
        },
        color: Colors.blueAccent,
        child: _activityType == "Follow-up"
            ?
            //build new tab
            TabBarView(
                controller: _tabController,
                children: [
                  _isLoadingEntries
                      ? _buildShimmerEffect()
                      : _committedEntries.isEmpty
                          ? Center(
                              child: Text(
                                'No New Entries',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView(
                                children: _committedEntries
                                    .map<Widget>(
                                        (entry) => _buildCommittedTile(entry))
                                    .toList(),
                              ),
                            ),
                  _drafts.isEmpty
                      ? Center(
                          child: Text(
                            'No Drafts Available',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: ListView(
                            children: _drafts
                                .map<Widget>((draft) => _buildDraftTile(draft))
                                .toList(),
                          ),
                        ),
                  _isLoadingEntries
                      ? _buildShimmerEffect()
                      : _committedEntries.isEmpty
                          ? Center(
                              child: Text(
                                'No committed entries',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView(
                                children: _committedEntries
                                    .map<Widget>(
                                        (entry) => _buildCommittedTile(entry))
                                    .toList(),
                              ),
                            ),
                ],
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _drafts.isEmpty
                      ? Center(
                          child: Text(
                            'No Drafts Available',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: ListView(
                            children: _drafts
                                .map<Widget>((draft) => _buildDraftTile(draft))
                                .toList(),
                          ),
                        ),
                  _isLoadingEntries
                      ? _buildShimmerEffect()
                      : _committedEntries.isEmpty
                          ? Center(
                              child: Text(
                                'No committed entries',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView(
                                children: _committedEntries
                                    .map<Widget>(
                                        (entry) => _buildCommittedTile(entry))
                                    .toList(),
                              ),
                            ),
                ],
              ),
      ),
      floatingActionButton: _activityType == "Baseline"
          ? FloatingActionButton(
              tooltip: 'Add New Entry',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/form_page',
                  arguments: {
                    'form_id': _formId,
                    'form_title': _formTitle,
                    'activity_type': _activityType,
                    'draft': null,
                  },
                ).then((_) {
                  _loadDrafts();
                });
              },
            )
          : FloatingActionButton(
              tooltip: 'Follow Up',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                // fetch follow up entries
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final regionId = auth.regionId ?? '1';
                await auth.apiService
                    .fetchFollowUpEntriesFromApi(regionId, _formId!);

                // Reload committed entries after fetching follow-up data
                setState(() {
                  _isLoadingEntries = true;
                  _loadEntries().then((_) {
                    _isLoadingEntries = false;
                  });
                });
              }),
    );
  }
}
