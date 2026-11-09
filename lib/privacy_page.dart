import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rewarded_ads.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, this.ads});
  final RewardedAdsController? ads;
  static final _policy = rootBundle.loadString('assets/privacy-policy.txt');

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffff9e9),
    appBar: AppBar(title: const Text('隱私權與廣告設定')),
    body: FutureBuilder<String>(
      future: _policy,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (ads != null)
            ListenableBuilder(
              listenable: ads!,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ads!.settings.production
                        ? '自選獎勵式廣告'
                        : '目前為官方測試廣告，不會產生收益。',
                  ),
                  if (ads!.privacyOptionsRequired)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FilledButton.tonal(
                        onPressed: ads!.busy
                            ? null
                            : () async {
                                await ads!.openPrivacyOptions();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ads!.status)),
                                  );
                                }
                              },
                        child: const Text('管理廣告隱私選擇'),
                      ),
                    ),
                  const Divider(height: 32),
                ],
              ),
            ),
          if (snapshot.hasData)
            SelectableText(
              snapshot.data!,
              style: const TextStyle(fontSize: 15, height: 1.8),
            )
          else if (snapshot.hasError)
            const Text('政策暫時無法讀取。請聯絡 info@foodbuyer.com.hk。')
          else
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'info@foodbuyer.com.hk'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('聯絡電郵已複製')));
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('複製聯絡電郵'),
          ),
        ],
      ),
    ),
  );
}
