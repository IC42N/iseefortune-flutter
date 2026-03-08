class PlacePredictionRequest {
  final String userWallet;
  final int lamports;
  final int number;

  PlacePredictionRequest({required this.userWallet, required this.lamports, required this.number});

  // Used when sendng JSON to the API
  Map<String, dynamic> toJson() => {'user_wallet': userWallet, 'lamports': lamports, 'number': number};
}
