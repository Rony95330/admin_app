import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import 'admin_collections.dart';
import 'managed_collection_page.dart';

class AdminCollectionsHubPage extends StatelessWidget {
  const AdminCollectionsHubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.collections,
  });

  final String title;
  final String subtitle;
  final List<AdminCollectionDefinition> collections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 176,
                  ),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ManagedCollectionPage(definition: collection),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.orange.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  collection.icon,
                                  color: AppColors.orange,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                collection.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                collection.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
