unit UConst;

{ Copyright (c) 2016 by Albert Molina

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  This unit is a part of the PascalCoin Project, an infinitely scalable
  cryptocurrency. Find us here:
  Web: https://www.pascalcoin.org
  Source: https://github.com/PascalCoin/PascalCoin

  If you like it, consider a donation using Bitcoin:
  16K3HCZRhFUtM8GdWRcfKeaa6KsuyxZaYk

  THIS LICENSE HEADER MUST NOT BE REMOVED.
}

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

{$I ./../config.inc}

{$IFNDEF FPC}
  // See http://wiki.freepascal.org/Code_Conversion_Guide
type
  PtrInt = NativeInt;
  PtrUInt = NativeUInt;
  TThreadID = NativeUInt;
{$ENDIF}

Const
  CT_Genesis_Magic_String_For_Old_Block_Hash :
    String =
    '(c) Albert Molina - Genesis block at same time than BitCoin Block 424720 Hash 000000000000000001cc41ff7846264718ef0a15f97f532a98277bd5f6820b89';

  CT_Zero_Block_Proof_of_work_in_Hexa =
    {$IFDEF PRODUCTION}'00000003A29C32E84A539ADE24397D41D30116A6FAFEC17B7D9CED68A4238C92'{$ELSE}{$IFDEF TESTNET}''{$ELSE}{$ENDIF}{$ENDIF};


  CT_NetServer_Port = {$IFDEF PRODUCTION}4004{$ELSE}{$IFDEF TESTNET}4204{$ELSE}{$ENDIF}{$ENDIF};
  CT_JSONRPCMinerServer_Port = {$IFDEF PRODUCTION}4009{$ELSE}{$IFDEF TESTNET}4209{$ELSE}{$ENDIF}{$ENDIF};
  CT_JSONRPC_Port = {$IFDEF PRODUCTION}4003{$ELSE}{$IFDEF TESTNET}4203{$ELSE}{$ENDIF}{$ENDIF};
  CT_AccountsPerBlock = 5;

  CT_NewLineSecondsAvg: Cardinal = {$IFDEF PRODUCTION}300{$ELSE}{$IFDEF TESTNET}30{$ELSE}{$ENDIF}{$ENDIF};
    // 60*5=300 seconds -> 5 minutes avg
    //   -> 1 day = 86400 seconds -> 1 year = 31536000 seconds (aprox)
    //   Each year = 105120 new blocks (aprox)
    //   -> *5 accounts per block = 525600 new accounts each year (aprox)

  CT_FirstReward: UInt64 = 1000000; // 4 decimals... First reward = 100,0000
  CT_MinReward: UInt64 = 10000; // 4 decimals... Min reward = 1,0000
  CT_NewLineRewardDecrease: Cardinal = {$IFDEF PRODUCTION}210240{$ELSE}{$IFDEF TESTNET}10000{$ENDIF}{$ENDIF};

  CT_WaitNewBlocksBeforeTransaction = {$IFDEF PRODUCTION}100{$ELSE}{$IFDEF TESTNET}10{$ENDIF}{$ENDIF};

  CT_RecoverFoundsWaitInactiveCount = {$IFDEF PRODUCTION}420480{$ELSE}{$IFDEF TESTNET}1000{$ENDIF}{$ENDIF};  // After 4 years... if an account has no operations, money will be a reward for a miner!
  CT_MaxFutureBlocksLockedAccount = {$IFDEF PRODUCTION}105120{$ELSE}{$IFDEF TESTNET}CT_RecoverFoundsWaitInactiveCount{$ENDIF}{$ENDIF}; // Maximum future blocks an account can be locked

  CT_MaxTransactionAmount = 1000000000000; // ... can be deleted
  CT_MaxTransactionFee = 100000000;
  CT_MaxWalletAmount = 10000000000000; // ... can be deleted
  //
  CT_MinCompactTarget_v1: Cardinal = {$IFDEF PRODUCTION}$19000000{$ELSE}{$IFDEF TESTNET}$17000000{$ELSE}{$ENDIF}{$ENDIF}; // First compact target of block 0
  CT_MinCompactTarget_v4: Cardinal = // Minimum compact target of block if using Protocol 4 or higher
    {$IFDEF ACTIVATE_RANDOMHASH_V4}
    {$IFDEF PRODUCTION}$12000000{$ELSE}{$IFDEF TESTNET}$08000000{$ELSE}{$ENDIF}{$ENDIF}
    {$ELSE}CT_MinCompactTarget_v1{$ENDIF};

  {$IFDEF ACTIVATE_RANDOMHASH_V4}
  CT_CompactTarget_Reset_v4: Cardinal = // First compact target of block if using Protocol 4 and RandomHash is Active
    {$IFDEF PRODUCTION}$16000000{$ELSE}$08000000{$ENDIF};
  {$ENDIF}
  CT_MinCompactTarget_v5: Cardinal = // Minimum compact target of block if using Protocol 5 or higher
    {$IFDEF PRODUCTION}$12000000{$ELSE}{$IFDEF TESTNET}$10000000{$ELSE}{$ENDIF}{$ENDIF};


  CT_CalcNewTargetBlocksAverage: Cardinal = 100;
  CT_CalcNewTargetLimitChange_SPLIT = 10;

  CT_MaxAccount : Cardinal = $FFFFFFFF;
  CT_MaxBlock : Cardinal = $FFFFFFFF;

  CT_MaxPayloadSize = 255; // Max payload size in bytes
  CT_MaxAccountDataSize = 32;
  CT_MaxFutureBlockTimestampOffset = 15;
  CT_MinNodesToCalcNAT = 4;

  CT_MinServersConnected = 2;
  CT_MaxServersConnected = 5;

  CT_MaxResendMemPoolOperations = 50000;

  CT_MaxClientsConnected = {$IFDEF FPC}140{$ELSE}80{$ENDIF};

  CT_BankToDiskEveryNBlocks = {$IFDEF PRODUCTION}100{$ELSE}100{$ENDIF}; // Build 1.5 changed from 500 to 100;

  CT_NID_secp256k1 = 714;
  CT_NID_secp384r1 = 715;
  CT_NID_sect283k1 = 729;
  CT_NID_secp521r1 = 716;

  CT_Default_EC_OpenSSL_NID = CT_NID_secp256k1;

  CT_AccountInfo_ForSale = 1000;
  CT_AccountInfo_ForAccountSwap = 1001;
  CT_AccountInfo_ForCoinSwap = 1002;

  CT_HashLockKey_MinBytes = 4;
  CT_HashLockKey_MaxBytes = 128;

  CT_PROTOCOL_1 = 1;
  CT_PROTOCOL_2 = 2;
  CT_PROTOCOL_3 = 3;
  CT_PROTOCOL_4 = 4;
  CT_PROTOCOL_5 = 5;
  CT_PROTOCOL_6 = 6;
  CT_PROTOCOL_MAX = CT_PROTOCOL_6;
  CT_BUILD_PROTOCOL = CT_PROTOCOL_5;

  CT_BlockChain_Protocol_Available: Word = 5; // Protocol 5 flag
  CT_Protocol_Upgrade_v2_MinBlock = {$IFDEF PRODUCTION}115000{$ELSE}50{$ENDIF};
  CT_Protocol_Upgrade_v3_MinBlock = {$IFDEF PRODUCTION}210000{$ELSE}250{$ENDIF};
  CT_Protocol_Upgrade_v4_MinBlock = {$IFDEF PRODUCTION}260000{$ELSE}400{$ENDIF};
  CT_Protocol_Upgrade_v5_MinBlock = {$IFDEF PRODUCTION}378000{$ELSE}500{$ENDIF};
  CT_Protocol_Upgrade_v6_MinBlock = {$IFDEF PRODUCTION}999999999{$ELSE}999999999{$ENDIF}; // TODO: ALLOW V6 activate setting a valid "min block" value


  CT_MagicNetIdentification = {$IFDEF PRODUCTION}$0A043580{$ELSE}$05000005{$ENDIF};

  CT_NetProtocol_Version: Word = 14;
  // IMPORTANT NOTE!!!
  // NetProtocol_Available MUST BE always >= NetProtocol_version
  CT_NetProtocol_Available: Word = {$IFDEF PRODUCTION}15{$ELSE}15{$ENDIF};

  CT_MaxAccountOperationsPerBlockWithoutFee = 1;
  CT_AllowPropagate0feeOperations = False;

  CT_SafeBoxBankVersion : Word = 3; // Protocol 2 upgraded safebox version from 2 to 3

  CT_MagicIdentificator: String = {$IFDEF PRODUCTION}'PascalCoin'{$ELSE}'PascalCoin_TESTNET'{$ENDIF}; //

  CT_PascalCoin_Data_Folder : String = {$IFDEF PRODUCTION}'PascalCoin'{$ELSE}'PascalCoin_TESTNET'{$ENDIF}; //

  CT_PseudoOp_Reward = $0;
  // Value of Operations type in Protocol 1
  CT_Op_Transaction = $01;
  CT_Op_Changekey = $02;
  CT_Op_Recover = $03;
  // Protocol 2 new operations
  CT_Op_ListAccountForSale = $04;
  CT_Op_DelistAccount = $05;
  CT_Op_BuyAccount = $06;
  CT_Op_ChangeKeySigned = $07;
  CT_Op_ChangeAccountInfo = $08;
  // Protocol 3 new operations
  CT_Op_MultiOperation = $09;  // PIP-0017
  // Protocol 4 new operations
  CT_Op_Data = $0A;            // PIP-0016

  CT_Protocol_v3_PIP11_Percent = 20; // PIP-0011 20% Percent proposed and voted by PIP-0011

  {$IFDEF PRODUCTION}
  CT_Hardcoded_RandomHash_Table_Filename = 'HardcodedRH_367700.randomhash';
  CT_Hardcoded_RandomHash_Table_HASH = '72F40C806694988151DC30672B2667362AC42A08B84F62D31AE8F4B7623A6D7B';
  {$ENDIF}

  CT_PseudoOpSubtype_Miner                = 1;
  CT_PseudoOpSubtype_Developer            = 2;

  CT_OpSubtype_TransactionSender          = 11;
  CT_OpSubtype_TransactionReceiver        = 12;
  CT_OpSubtype_BuyTransactionBuyer        = 13;
  CT_OpSubtype_BuyTransactionTarget       = 14;
  CT_OpSubtype_BuyTransactionSeller       = 15;
  CT_OpSubtype_SwapTransactionSender      = 16;
  CT_OpSubtype_SwapTransactionTarget      = 17;
  CT_OpSubtype_SwapTransactionReceiver    = 18;
  CT_OpSubtype_ChangeKey                  = 21;
  CT_OpSubtype_Recover                    = 31;
  CT_OpSubtype_ListAccountForPublicSale   = 41;
  CT_OpSubtype_ListAccountForPrivateSale  = 42;
  CT_OpSubtype_ListAccountForAccountSwap  = 43;
  CT_OpSubtype_ListAccountForCoinSwap     = 44;
  CT_OpSubtype_DelistAccount              = 51;
  CT_OpSubtype_BuyAccountBuyer            = 61;
  CT_OpSubtype_BuyAccountTarget           = 62;
  CT_OpSubtype_BuyAccountSeller           = 63;
  CT_OpSubtype_ChangeKeySigned            = 71;
  CT_OpSubtype_ChangeAccountInfo          = 81;
  CT_OpSubtype_MultiOperation_Global      = 91;
  CT_OpSubtype_MultiOperation_AccountInfo = 92;
  CT_OpSubtype_Data_GlobalInfo            = 101;
  CT_OpSubtype_Data_Sender                = 102;
  CT_OpSubtype_Data_Signer                = 103;
  CT_OpSubtype_Data_Receiver              = 104;

  CT_ClientAppVersion : String = {$IFDEF PRODUCTION}'5.7'{$ELSE}{$IFDEF TESTNET}'TESTNET 5.7'{$ELSE}{$ENDIF}{$ENDIF};

  CT_Discover_IPs = {$IFDEF PRODUCTION}'bpascal1.dynamic-dns.net;bpascal2.dynamic-dns.net;pascalcoin1.dynamic-dns.net;pascalcoin2.dynamic-dns.net;pascalcoin1.dns1.us;pascalcoin2.dns1.us;pascalcoin1.dns2.us;pascalcoin2.dns2.us'
                    {$ELSE}'pascaltestnet1.dynamic-dns.net;pascaltestnet2.dynamic-dns.net;pascaltestnet1.dns1.us;pascaltestnet2.dns1.us'{$ENDIF};

  CT_TRUE_FALSE : Array[Boolean] Of String = ('FALSE','TRUE');

  CT_MAX_0_fee_operations_per_block_by_miner = {$IFDEF PRODUCTION}30000{$ELSE}{$IFDEF TESTNET}3000{$ELSE}{$ENDIF}{$ENDIF};
  CT_MAX_Operations_per_block_by_miner =  {$IFDEF PRODUCTION}500000{$ELSE}{$IFDEF TESTNET}50000{$ELSE}{$ENDIF}{$ENDIF};

  CT_MAX_MultiOperation_Senders = 100;
  CT_MAX_MultiOperation_Receivers = 1000;
  CT_MAX_MultiOperation_Changers = 100;

  CT_DEFAULT_MaxSafeboxSnapshots = 10;

  CT_MOLINA  = 1;
  CT_MOLINA_DECIMAL = {$IFDEF FPC}Real(CT_MOLINA/1000.0);{$ELSE}0.0001;{$ENDIF}

  CT_DEFAULT_PAY_TO_KEY_MAX_MOLINAS = 5000;

  CT_ACTIVATE_RANDOMHASH_V4 = {$IFDEF ACTIVATE_RANDOMHASH_V4}True{$ELSE}False{$ENDIF};

  // Represents a non-existent account number
  // (chosen as the last account in safebox, generated in year 6101)
  CT_AccountNo_NUL = High(Cardinal);

  // App Params
  CT_PARAM_GridAccountsStream = 'GridAccountsStreamV2';
  CT_PARAM_GridAccountsPos = 'GridAccountsPos';
  CT_PARAM_DefaultFee = 'DefaultFee';
  CT_PARAM_InternetServerPort = 'InternetServerPort';
  {$IFDEF TESTNET}CT_PARAM_AutomaticMineWhenConnectedToNodes = 'AutomaticMineWhenConnectedToNodes';{$ENDIF}
  CT_PARAM_MinerPrivateKeyType = 'MinerPrivateKeyType';
  CT_PARAM_MinerPrivateKeySelectedPublicKey = 'MinerPrivateKeySelectedPublicKey';
  CT_PARAM_SaveLogFiles = 'SaveLogFiles';
  CT_PARAM_SaveDebugLogs = 'SaveDebugLogs';
  CT_PARAM_ShowLogs = 'ShowLogs';
  CT_PARAM_MinerName = 'MinerName';
  CT_PARAM_FirstTime = 'FirstTime';
  CT_PARAM_ShowModalMessages = 'ShowModalMessages';
  {$IFDEF TESTNET}CT_PARAM_MaxCPUs = 'MaxCPUs'; {$ENDIF} //deprecated
  CT_PARAM_PeerCache = 'PeerCache';
  CT_PARAM_TryToConnectOnlyWithThisFixedServers = 'TryToConnectOnlyWithFixedServers';
  CT_PARAM_JSONRPCMinerServerPort = 'JSONRPCMinerServerPort';
  CT_PARAM_JSONRPCMinerServerActive = 'JSONRPCMinerServerActive';
  CT_PARAM_JSONRPCEnabled = 'JSONRPCEnabled';
  CT_PARAM_JSONRPCAllowedIPs = 'JSONRPCAllowedIPs';



implementation

end.
