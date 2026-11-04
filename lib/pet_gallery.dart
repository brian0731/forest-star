import 'package:flutter/material.dart';
import 'game.dart';

/// One scrollable album, including friends the player has not met yet.
class PetGalleryPage extends StatelessWidget {
  const PetGalleryPage({
    super.key,
    required this.state,
    required this.selected,
  });
  final GameState state;
  final int selected;
  static const ink = Color(0xff39482f);
  static const green = Color(0xff426b48);

  @override
  Widget build(BuildContext context) {
    final met = state.unlocked.where((value) => value).length;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Scaffold(
      backgroundColor: const Color(0xffe8eddb),
      appBar: AppBar(
        backgroundColor: const Color(0xfffff6df),
        foregroundColor: ink,
        title: const Text(
          '全部寵物',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: const BackButton(),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/storybook/companions.webp',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(.28),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: CustomScrollView(
                  key: const PageStorageKey('pet_gallery_scroll'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff6df),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xffc9b782)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x182e492d),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '森林夥伴圖鑑',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '已結識 $met / ${friends.length} 隻',
                                style: const TextStyle(
                                  color: green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '向下捲動，看看每位朋友。\n點選寵物，返回小屋查看牠。',
                                style: TextStyle(
                                  color: Color(0xff6e7b5f),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 205,
                          mainAxisExtent: 236 + (scale - 1).clamp(0, 3) * 100,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, id) => _PetCard(
                            state: state,
                            id: id,
                            selected: selected == id,
                          ),
                          childCount: friends.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.state,
    required this.id,
    required this.selected,
  });
  final GameState state;
  final int id;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final friend = friends[id];
    final met = state.unlocked[id];
    final label = met
        ? 'Lv.${state.levels[id]} · ${friend.role}'
        : '尚未結識 · ${friend.role}';
    return Semantics(
      label: '${friend.name}，$label，點選返回小屋',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        key: ValueKey('pet_gallery_$id'),
        color: selected ? const Color(0xffffefbf) : const Color(0xfffff8e9),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: selected ? 4 : 1,
        shadowColor: const Color(0x44283e2b),
        child: InkWell(
          onTap: () => Navigator.pop(context, id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xffad873f)
                    : const Color(0xffd8c898),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              friend.color.withValues(alpha: .35),
                              friend.color.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      Image.asset(
                        id < 6
                            ? 'assets/storybook/character-$id.png'
                            : 'assets/pets/character-$id.png',
                        fit: BoxFit.contain,
                        opacity: AlwaysStoppedAnimation(met ? 1 : .75),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Text(
                          '#${(id + 1).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff829072),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: 21,
                            color: Color(0xffa9833c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  friend.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PetGalleryPage.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PetGalleryPage.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  met
                      ? (state.evolutions[id] > 0
                            ? '進化 ${state.evolutions[id]} / 2'
                            : '一起冒險吧')
                      : (id >= 6 ? '星願轉珠可結識' : '到小屋結識新朋友'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xff8b7853),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
