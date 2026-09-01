import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account_repository.dart';

/// Accounts used by pickers on the Add Expense / Add Income / Transfer screens.
final accountsProvider = FutureProvider<AccountsPayload>(
    (ref) => ref.read(accountRepositoryProvider).list());
