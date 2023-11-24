import 'package:dinogrow/Models/connect_data.dart';
import 'package:dinogrow/Models/savescore_anchor.dart';
import 'package:flutter/services.dart';
import 'package:solana/anchor.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:solana_buffer/buffer.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:http/http.dart';

Future<String> saveScore(ConnectData connectData, BigInt score) async {
  String result = "";
  switch (connectData.selectedChain) {
    case Chain.bsc:
      final contractAddress = web3.EthereumAddress.fromHex(
          "0xCddF418D9838d440913c68e72Aa3Cd497E7a4f78");
      result = await _saveScoreEvm(
          connectData.rpc!, contractAddress, score, connectData.credEvm!);

    case Chain.polygon:
      final contractAddress = web3.EthereumAddress.fromHex(
          "0x5c10ac614d72644219b7E52FE46C41d5159E05D4");
      result = await _saveScoreEvm(
          connectData.rpc!, contractAddress, score, connectData.credEvm!);
    case Chain.solana:
      result = await _saveScoreSolana(
          connectData.rpc!, score, connectData.credSolana!);
    case null:
  }
  return result;
}

Future<String> _saveScoreSolana(
    String rpc, BigInt score, Ed25519HDKeyPair credentials) async {
  String wsUrl = rpc.replaceFirst('https', 'wss');
  final client = SolanaClient(
    rpcUrl: Uri.parse(rpc),
    websocketUrl: Uri.parse(wsUrl),
  );
  final programIdPublicKey = Ed25519HDPublicKey.fromBase58(
      "5CUttLFg8AZ2hPbiaroC5QPmjA8aDzJucFqXZVBRMU8Q");
  final systemProgramId =
      Ed25519HDPublicKey.fromBase58(SystemProgram.programId);
  final profilePda = await Ed25519HDPublicKey.findProgramAddress(
    seeds: [
      Buffer.fromString("random"),
      credentials.publicKey.bytes,
    ],
    programId: programIdPublicKey,
  );
  String method = "updatescore";
  final result = await client.rpcClient
      .getAccountInfo(
        profilePda.toBase58(),
        commitment: Commitment.confirmed,
        encoding: Encoding.jsonParsed,
      )
      .value;
  if (result == null) {
    method = "savescore";
  }
  final saveScore = SaveScoreAnchor(score: score, user: credentials.publicKey);
  final instruction = await AnchorInstruction.forMethod(
    programId: programIdPublicKey,
    method: method,
    arguments: ByteArray(saveScore.toBorsh().toList()),
    accounts: <AccountMeta>[
      AccountMeta.writeable(pubKey: profilePda, isSigner: false),
      AccountMeta.writeable(pubKey: credentials.publicKey, isSigner: true),
      AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
    ],
    namespace: 'global',
  );
  final message = Message(instructions: [instruction]);
  final signature = await client.sendAndConfirmTransaction(
    message: message,
    signers: [credentials],
    commitment: Commitment.confirmed,
  );
  return signature;
}

Future<String> _saveScoreEvm(String rpc, EthereumAddress contractAddress,
    BigInt score, web3.Credentials credentials) async {
  final abi = await rootBundle.loadString('assets/abi.json');
  final contract = web3.DeployedContract(
      web3.ContractAbi.fromJson(abi, 'userScores'), contractAddress);
  final function = contract.function("saveScore");
  final httpClient = Client();
  final ethClient = web3.Web3Client(rpc, httpClient);
  final gasPrice = await ethClient.getGasPrice();
  final chainId = await ethClient.getChainId();
  final result = await ethClient.sendTransaction(
    credentials,
    web3.Transaction.callContract(
      contract: contract,
      function: function,
      parameters: [score, credentials.address],
      from: credentials.address,
      gasPrice: web3.EtherAmount.inWei(gasPrice.getInWei),
    ),
    chainId: chainId.toInt(),
  );
  return result;
}
