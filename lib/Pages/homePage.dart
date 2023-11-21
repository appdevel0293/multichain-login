import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:solana/solana.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:http/http.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final storage = const FlutterSecureStorage();
  Image? _image;
  String? _chain = ' ';
  String? _balance;
  String? _address = '';
  String truncAddress = '';

  @override
  void initState() {
    super.initState();
    _readChain();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).go("/selectChain");
        },
        backgroundColor: Colors.white.withOpacity(0.3),
        child: const Icon(
          Icons.arrow_back,
        ),
      ),
      appBar: AppBar(
        title: Text("Connected to $_chain"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Text(truncAddress),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _address!));
                },
              ),
            ],
          ),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.transparent,
                child: _image,
              ),
              Text(
                _balance ?? 'Loading...',
                style: const TextStyle(fontSize: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _readChain() async {
    String rpc = '';
    await dotenv.load(fileName: ".env");
    final chain = await storage.read(key: 'chain');
    final mnemonic = await storage.read(key: 'mnemonic');
    setState(() {
      _chain = chain;
    });
    switch (chain) {
      case 'bsc':
        rpc = dotenv.env['QUICKNODE_BSC_TESTNET'].toString();
        _image = Image.asset(
          "assets/binance.png",
        );
        _balanceEvm(rpc, mnemonic);
      case 'polygon':
        rpc = dotenv.env['QUICKNODE_POLYGON_TESTNET'].toString();
        _image = Image.asset(
          "assets/polygon.png",
        );
        _balanceEvm(rpc, mnemonic);
      case 'solana':
        rpc = dotenv.env['QUICKNODE_SOLANA_DEVNET'].toString();
        _image = Image.asset(
          "assets/solana.png",
        );
        _balanceSolana(rpc, mnemonic);
    }
  }

  void _balanceSolana(String rpc, String? mnemonic) async {
    final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic!);
    _address = keypair.address;
    String wsUrl = rpc.replaceFirst('https', 'wss');
    final client = SolanaClient(
      rpcUrl: Uri.parse(rpc),
      websocketUrl: Uri.parse(wsUrl),
    );
    final getBalance = await client.rpcClient
        .getBalance(_address!, commitment: Commitment.confirmed);
    final balance = (getBalance!.value) / lamportsPerSol;
    setState(() {
      _balance = balance.toString();
      truncAddress = truncateString(_address!);
    });
  }

  void _balanceEvm(String rpc, String? mnemonic) async {
    final hex = bip39.mnemonicToSeedHex(mnemonic!);
    final address = web3.EthPrivateKey.fromHex(hex).address;

    var httpClient = Client();
    var ethClient = web3.Web3Client(rpc, httpClient);

    web3.EtherAmount balance = await ethClient.getBalance(address);
    _address = address.toString();
    setState(() {
      truncAddress = truncateString(_address!);
      _balance = balance.getValueInUnit(web3.EtherUnit.ether).toString();
    });
  }
}

String truncateString(String input) {
  String first = input.substring(0, 3);
  String last = input.substring(input.length - 3);
  return '$first...$last';
}
