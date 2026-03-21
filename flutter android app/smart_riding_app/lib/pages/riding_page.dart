import 'package:flutter/material.dart';
import '../common/constants/app_colors.dart';
import '../common/constants/app_spacing.dart';
import '../common/constants/app_typography.dart';

/// 骑行信息页面
class RidingPage extends StatelessWidget {
  const RidingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('骑行数据'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _showAiSuggestion(context),
            tooltip: 'AI建议',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 本周骑行标题
              Text(
                '本周骑行',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              // 统计卡片
              _buildStatsCard(),
              const SizedBox(height: AppSpacing.lg),

              // 历史轨迹标题
              Text(
                '历史轨迹',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              // 地图占位
              _buildMapPlaceholder(),
              const SizedBox(height: AppSpacing.lg),

              // 骑行记录标题
              Text(
                '骑行记录',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              // 骑行记录列表
              _buildRidingRecords(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('128.5', 'km', '总里程'),
          _buildStatItem('8h 32m', '', '总时长'),
          _buildStatItem('12', '次', '骑行次数'),
          _buildStatItem('15.2', 'km/h', '平均速度'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String unit, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '地图加载中...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidingRecords() {
    final records = [
      {'date': '3-15', 'time': '08:30', 'distance': '5.2km', 'duration': '25min'},
      {'date': '3-14', 'time': '18:15', 'distance': '3.1km', 'duration': '15min'},
      {'date': '3-13', 'time': '07:45', 'distance': '8.5km', 'duration': '42min'},
      {'date': '3-12', 'time': '17:30', 'distance': '4.8km', 'duration': '22min'},
      {'date': '3-11', 'time': '08:00', 'distance': '6.2km', 'duration': '30min'},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final record = records[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(
                  Icons.directions_bike,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record['date']} ${record['time']}',
                      style: AppTypography.titleMedium,
                    ),
                    Text(
                      '时长: ${record['duration']}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Text(
                record['distance']!,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAiSuggestion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXLarge),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI骑行建议',
                  style: AppTypography.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '本周骑行表现不错！您已累计骑行128.5公里，建议：',
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSuggestionItem('保持规律骑行习惯对健康有益'),
            _buildSuggestionItem('注意检查轮胎气压，确保骑行安全'),
            _buildSuggestionItem('建议进行一次全面车辆保养'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
