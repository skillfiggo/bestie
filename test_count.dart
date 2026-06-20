import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  SupabaseClient client = SupabaseClient('url', 'key');
  final count = await client.from('profiles').count(CountOption.exact);
  print(count);
}
