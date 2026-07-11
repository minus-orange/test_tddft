# TDDFT GPU次段階設計書の履歴

このdirectoryには、現行の[英語版v5](../tddft_gpu_next_stage_design_en.md)と
[日本語版v5](../tddft_gpu_next_stage_design_ja.md)より前の設計書を保存しています。

v1-v4作成時点では作業文書がGit管理されていなかったため、Codex sessionの
patch記録から原文を復元しました。SHA-256は復元内容が変わっていないことを
確認するためのhash値です。

| revision | 原文の言語 | patch時刻 (UTC) | SHA-256 |
|---|---|---|---|
| [v1](tddft_gpu_next_stage_design_v1.md) | 日本語。source識別子と専門用語は英語 | 2026-07-10 11:57:21 | `26a208d6e87577fe998e0f74b34e6bfcbc2d6e3098457b14808b35f6ab616da4` |
| [v2](tddft_gpu_next_stage_design_v2.md) | 日本語。source識別子と専門用語は英語 | 2026-07-10 14:10:14 | `d9c026efab9af038560a38931f642bf6b921b2462b2d93e57691d6c39e92345f` |
| [v3](tddft_gpu_next_stage_design_v3.md) | 日本語。source識別子と専門用語は英語 | 2026-07-10 21:05:43 | `5bb0bc54dce77db94542a6e00e0c3951a739c154ebd01cc15ab6a6355879e7cd` |
| [v4](tddft_gpu_next_stage_design_v4.md) | 英語 | 2026-07-10 21:35:48 | `eef5f591534f3bb6936992df0bc0eb746e6b1e529029608ff4b3a718867fe526` |

## 読み方

- v1-v4は監査用の原本なので編集しません。
- v1-v3内の英語は主に配列名、routine名、OpenACC用語です。別の英語版を
  保守していたわけではありません。
- 現在の実装仕様を読む場合は、用語解説を追加した日本語版v5を使用します。
- 過去判断の正確な表現を確認するときだけ、該当revisionの原文を参照します。
