/// Datele proiectului Supabase în care se salvează sarcinile.
///
/// Cheia „publishable” e făcută să stea în aplicație: singură nu dă acces la
/// nimic. Fiecare instalare primește un cont anonim, iar regulile din baza de
/// date (RLS, vezi `database/schema.sql`) lasă fiecare cont să vadă doar
/// sarcinile lui. Cheia „secret” și parola bazei NU se pun niciodată aici.
abstract final class SupabaseConfig {
  static const url = 'https://ytugnoacdplwmsjsuqet.supabase.co';
  static const publishableKey =
      'sb_publishable_Yj-L5l4KVSNpslxhoI3-FA_-zIkCf8-';
}
