unit UPoolMining;

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

Uses
{$IFnDEF FPC}
  Windows,
{$ELSE}
  {LCLIntf, LCLType, LMessages,}
{$ENDIF}
  UTCPIP, SysUtils, UThread, SyncObjs, Classes, UJSONFunctions, UPCEncryption, UNode,
  UCrypto, UAccounts, UConst, UBlockChain, UBaseTypes, UPCDataTypes, UOpTransaction,
  UPCAccountsOrdenations,
  {$IFNDEF FPC}System.Generics.Collections{$ELSE}Generics.Collections{$ENDIF};

Const
  CT_PoolMining_Method_STATUS = 'status';
  CT_PoolMining_Method_MINER_NOTIFY = 'miner-notify'; // Server message to clients to update miners PoW data
  CT_PoolMining_Method_MINER_SUBMIT = 'miner-submit'; // Client message to server to notify a PoW found
  CT_PoolMining_Method_MINER_RANDOMHASH = 'rh'; // Client message to server to calculate a hash based on RandomHash algo
  CT_PoolMining_Method_MINER_RANDOMHASH2 = 'rh2'; // Client message to server to calculate a hash based on RandomHash2 algo

  CT_PoolMining_Method_STRATUM_MINING_AUTHORIZE = 'mining.authorize';
  CT_PoolMining_Method_STRATUM_MINING_SUBSCRIBE = 'mining.subscribe';
  CT_PoolMining_Method_STRATUM_MINING_SET_DIFFICULTY = 'mining.set_difficulty';
  CT_PoolMining_Method_STRATUM_MINING_NOTIFY = 'mining.notify';
  CT_PoolMining_Method_STRATUM_MINING_SUBMIT = 'mining.submit';

Type
  TMinerValuesForWork = Record
     block : Cardinal;
     version : Word;
     part1 : TRawBytes;
     payload_start : TRawBytes;
     part3 : TRawBytes;
     target : Cardinal;
     timestamp : Cardinal;
     target_pow : TRawBytes;
     // Stratum information
     jobid : String;
     extraNOnce2_Size : Integer;
     extraNOnce2_Used : TRawBytes;
  End;

  { TMinerValuesForWork_HELPER }

  TMinerValuesForWork_HELPER = record helper for TMinerValuesForWork
     function FinalPayload : TRawBytes;
     function IsStratum : Boolean;
  end;


  TProcessJSONObjectEvent = Procedure (json : TPCJSONObject; method : String) of object;

  { TJSONRPCTcpIpClient }

  TJSONRPCTcpIpClient = Class(TBufferedNetTcpIpClient)
  private
    FLastId : Cardinal;
    FLockProcessBuffer : TPCCriticalSection;
    FReceivedBuffer : TBytes;
    FLockReceivedBuffer : TPCCriticalSection;
    FPendingResponseMessages : TPCThreadList<Pointer>;
  protected
  public
    Constructor Create(AOwner : TComponent); override;
    Destructor Destroy; override;
    Procedure SendJSONRPCErrorResponse(const id : Variant; const error : String);
    Procedure SendJSONRPCResponse(result : TPCJSONObject; const id : Variant);
    Procedure SendJSONRPCMethod(const method : String; params : TPCJSONList; const id : Variant);
    Function SendJSONRPCMethodAndWait(const method : String; params : TPCJSONList; MaxWaitMiliseconds : Int64; resultObject : TPCJSONObject; processEventOnInvalid : TProcessJSONObjectEvent = Nil) : Boolean;
    Function DoProcessBuffer(SenderThread : TPCThread; MaxWaitMiliseconds : Cardinal; DeleteBufferOnExit : Boolean; var ResponseMethod : String; var jsonObject : TPCJSONObject) : Boolean;
    Function GetNewId : Cardinal;
  End;

  TPoolType = (ptSolomine,ptPoolSubscription);

  { TPoolMinerClient }

  TPoolMinerClient = Class(TJSONRPCTcpIpClient)
  private
    FMinerValuesForWork: TMinerValuesForWork;
    FOnMinerMustChangeValues: TNotifyEvent;
    FPassword: String;
    FPoolFinalMinerName: TRawBytes;
    FPoolType: TPoolType;
    FStratum_Target_PoW: TRawBytes;
    FUserName: String;
    FStratumAuthorized : Boolean;
    FStratum_ExtraNOnce2_Size: Integer;
    procedure SetMinerValuesForWork(const Value: TMinerValuesForWork);
  protected
    Procedure DoOnConnect; Override;
  public
    Constructor Create(AOwner : TComponent); override;
    Property OnMinerMustChangeValues : TNotifyEvent read FOnMinerMustChangeValues write FOnMinerMustChangeValues;
    Property MinerValuesForWork : TMinerValuesForWork read FMinerValuesForWork write SetMinerValuesForWork;
    Procedure SubmitBlockFound(Const MinerValuesToGenerateBlock : TMinerValuesForWork; const Payload: TRawBytes; Timestamp, NOnce: Cardinal; const AObtainedPoW : TRawBytes);
    Procedure DoProcessJSONObject(json : TPCJSONObject; ResponseMethod : String);
    Property PoolType : TPoolType read FPoolType write FPoolType;
    Property UserName : String read FUserName write FUserName;
    Property Password : String read FPassword write FPassword;
    Property PoolFinalMinerName : TRawBytes read FPoolFinalMinerName;
    Property Stratum_Target_PoW : TRawBytes read FStratum_Target_PoW;
    Property Stratum_Authorized : Boolean read FStratumAuthorized write FStratumAuthorized;
    Property Stratum_ExtraNOnce2_Size : Integer read FStratum_ExtraNOnce2_Size write FStratum_ExtraNOnce2_Size;
  End;

  TPoolMiningServer = Class;

  TPoolMiningServerThread = Class(TPCThread)
  private
    FPoolMiningServer : TPoolMiningServer;
  protected
    procedure BCExecute; override;
  public
    Constructor Create(APoolMiningServer : TPoolMiningServer);
    Destructor Destroy; override;
  End;


  { TPoolMiningServer }

  TPoolMiningServer = Class(TNetTcpIpServer)
  private
    FIncomingsCounter : Integer;
    FNodeNotifyEvents : TNodeNotifyEvents;
    FMinerAccountKey: TAccountKey;
    FMinerPayload: TRawBytes;
    FClientsWins: Integer;
    FClientsCount: Integer;
    FOnMiningServerNewBlockFound: TNotifyEvent;
    FPoolJobs : TPCThreadList<Pointer>;
    FPoolThread : TPoolMiningServerThread;
    FMinerOperations : TPCOperationsComp;
    FMaxOperationsPerBlock: Integer;
    FMax0FeeOperationsPerBlock: Integer;
    Procedure CheckMinerRecover(nbOperations: TPCOperationsComp);
    Procedure DoProcessJSON(json : TPCJSONObject; ResponseMethod : String; Client : TJSONRPCTcpIpClient);
    Procedure OnNodeNewBlock(Sender : TObject);
    Procedure OnNodeOperationsChanged(Sender : TObject);
    Function MinerSubmit(Client : TJSONRPCTcpIpClient; params : TPCJSONObject; const id : Variant) : Boolean;
    procedure SetMinerAccountKey(const Value: TAccountKey);
    procedure SetMinerPayload(const Value: TRawBytes);
    Procedure ClearPoolJobs;
    Procedure CaptureNewJobAndSendToMiners;
    Procedure SendJobToMiner(Operations : TPCOperationsComp; Client : TJSONRPCTcpIpClient; IsResponse : Boolean; idResponse : Variant);
    Procedure FillMinerOperations;
    procedure SetMax0FeeOperationsPerBlock(const Value: Integer);
    procedure SetMaxOperationsPerBlock(const Value: Integer);
  protected
    Procedure OnNewIncommingConnection(Sender : TObject; Client : TNetTcpIpClient); override;
    procedure SetActive(const Value: Boolean); override;
  public
    Constructor Create; override;
    Destructor Destroy; override;
    Property MinerAccountKey : TAccountKey read FMinerAccountKey write SetMinerAccountKey;
    Property MinerPayload : TRawBytes read FMinerPayload write SetMinerPayload;
    Procedure UpdateAccountAndPayload(AMinerAccountKey : TAccountKey; AMinerPayload : TRawBytes);
    Property ClientsCount : Integer read FClientsCount;
    Property ClientsWins : Integer read FClientsWins;
    Property OnMiningServerNewBlockFound : TNotifyEvent read FOnMiningServerNewBlockFound write FOnMiningServerNewBlockFound;
    Property Max0FeeOperationsPerBlock : Integer read FMax0FeeOperationsPerBlock write SetMax0FeeOperationsPerBlock;
    Property MaxOperationsPerBlock : Integer read FMaxOperationsPerBlock write SetMaxOperationsPerBlock;
  End;

Function TBytesToString(Const bytes : TBytes):AnsiString;

Const
  CT_TMinerValuesForWork_NULL : TMinerValuesForWork = (block:0;version:0;part1:Nil;payload_start:Nil;part3:Nil;target:0;timestamp:0;target_pow:Nil;jobid:'';extraNOnce2_Size:0;extraNOnce2_Used:Nil);

implementation

Uses ULog, Variants, UTime, UNetProtocol;

Type TPendingResponseMessage = Record
       sendDateTime : TDateTime;
       maxDateTime : TDateTime;
       id : Integer;
       method : String;
     end;
  PPendingResponseMessage = ^TPendingResponseMessage;

Function TBytesToString(Const bytes : TBytes):AnsiString;
Var i : Integer;
Begin
  Result := '';
  for i := 0 to high(bytes) do begin
    if (bytes[i]<32) then Result := Result+'#'+IntToHex(bytes[i],2)
    else if bytes[i]=ord('#') then Result := Result+'##'
    else Result := Result + ansichar(bytes[i]);
  end;
End;

{ TMinerValuesForWork_HELPER }

function TMinerValuesForWork_HELPER.FinalPayload: TRawBytes;
begin
  if IsStratum then begin
    // Check extraNOnce2 valid value
    while ( Self.extraNOnce2_Size>Length(Self.extraNOnce2_Used) ) do begin
      SetLength(Self.extraNOnce2_Used, Length(Self.extraNOnce2_Used) + 1);
      Self.extraNOnce2_Used[ High(Self.extraNOnce2_Used) ] := 48; // 48 = Char '0'
    end;
  end;
  SetLength(Result, Length(Self.payload_start) + Length(Self.extraNOnce2_Used) );
  Move(Self.payload_start[0],Result[0],Length(Self.payload_start));
  Move(Self.extraNOnce2_Used[0],Result[Length(Self.payload_start)],Length(Self.extraNOnce2_Used));
end;

function TMinerValuesForWork_HELPER.IsStratum: Boolean;
begin
  Result := Length(Self.jobid)>0;
end;

{ TJSONRPCTcpIpClient }

constructor TJSONRPCTcpIpClient.Create(AOwner: TComponent);
begin
  inherited;
  FLastId := 1;
  SetLength(FReceivedBuffer,0);
  FLockProcessBuffer := TPCCriticalSection.Create('TJSONRPCTcpIpClient_LockProcessBuffer');
  FLockReceivedBuffer := TPCCriticalSection.Create('TJSONRPCTcpIpClient_LockReceivedBuffer');
  FPendingResponseMessages := TPCThreadList<Pointer>.Create('TJSONRPCTcpIpClient_PendingResponseMessages');
end;

destructor TJSONRPCTcpIpClient.Destroy;
var P : PPendingResponseMessage;
  l : TList<Pointer>;
  i : Integer;
begin
  l := FPendingResponseMessages.LockList;
  try
    for i:=0 to l.count-1 do begin
      P:=l[i];
      Dispose(P);
    end;
    l.clear;
  finally
    FPendingResponseMessages.UnlockList;
  end;
  FreeAndNil(FLockReceivedBuffer);
  FreeAndNil(FLockProcessBuffer);
  SetLength(FReceivedBuffer,0);
  FreeAndNil(FPendingResponseMessages);
  inherited;
end;

function TJSONRPCTcpIpClient.DoProcessBuffer(SenderThread : TPCThread; MaxWaitMiliseconds : Cardinal; DeleteBufferOnExit : Boolean; var ResponseMethod : String; var jsonObject : TPCJSONObject) : Boolean;
var last_bytes_read : Integer;
  jsonData : TPCJSONData;
  tc : TTickCount;
  ms : TMemoryStream;
  i,lasti : Integer;
  continue : Boolean;
  procedure FlushBufferPendingMessages(doSearchId : Boolean; idValue : Integer);
  var l : TList<Pointer>;
    i : Integer;
    P : PPendingResponseMessage;
  Begin
    l := FPendingResponseMessages.LockList;
    Try
      for i := l.count-1 downto 0 do begin
        P := l[i];
        if (doSearchId) And (idValue=P^.id) then begin
          ResponseMethod:=P^.method;
          Dispose(P);
          l.Delete(i);
        end else if (P^.maxDateTime<now) then begin
          TLog.NewLog(lterror,Classname,'Deleting a Pending response message id:'+inttostr(P^.id)+' method:'+P^.method);
          Dispose(P);
          l.Delete(i);
        end;
      end;
    finally
      FPendingResponseMessages.UnlockList;
    end;
  end;
var PartialBuffer : TBytes;
  Function ProcessPartialBuffer : Boolean;
  Var i,istart : Integer;
    aux : TBytes;
  begin
    result := false;
    i := 0; istart :=0;
    while (i<=high(FReceivedBuffer)) do begin
      if FReceivedBuffer[i]<32 then begin
        if i=istart then inc(istart)
        else break;
      end else begin
      end;
      inc(i);
    end;
    if (i>0) And (i>istart) And (i<=High(FReceivedBuffer)) then begin
      SetLength(PartialBuffer,i-istart);
      move(FReceivedBuffer[istart],PartialBuffer[0],i-istart);
      // Inc i until valid char
      while (i<=High(FReceivedBuffer)) And (FReceivedBuffer[i]<32) do inc(i);
      // i is the first valid pos for next buffer
      if i<=High(FReceivedBuffer) then begin
        setlength(aux,length(FReceivedBuffer)-i);
        move(FReceivedBuffer[i],aux[0],length(aux));
        SetLength(FReceivedBuffer,length(aux));
        move(aux[0],FReceivedBuffer[0],length(aux));
      end else begin
        // empty next buffer
        SetLength(FReceivedBuffer,0);
      end;
      Result := true;
    end;
  end;
begin
  Result := false;
  ResponseMethod := '';
  tc := TPlatform.GetTickCount;
  If Not TPCThread.TryProtectEnterCriticalSection(Self,MaxWaitMiliseconds,FLockProcessBuffer) then Exit;
  try
    if Assigned(SenderThread) then continue := Not SenderThread.Terminated
    else continue := true;
    while (Connected) And ((TPlatform.GetTickCount<=(tc+MaxWaitMiliseconds)) Or (MaxWaitMiliseconds=0)) And (continue) do begin
      last_bytes_read := 0;
      ms := ReadBufferLock;
      try
        if (ms.Size)>0 then begin
          lasti := length(FReceivedBuffer);
          setLength(FReceivedBuffer,length(FReceivedBuffer)+ms.Size);
          move(ms.Memory^,FReceivedBuffer[lasti],ms.Size);
          last_bytes_read := ms.Size;
          ms.Size := 0;
        end;
      finally
        ReadBufferUnlock;
      end;
      If ProcessPartialBuffer then begin
        // Decode
        jsonData := TPCJSONData.ParseJSONValue(PartialBuffer);
        if Assigned(jsonData) then begin
          Try
            if jsonData is TPCJSONObject then begin
              jsonObject.Assign(jsonData);
              If (Not jsonObject.IsNull('id')) then begin
                // Is a Response!
                FlushBufferPendingMessages(true,jsonObject.AsInteger('id',0));
              end;
              TLog.NewLog(ltdebug,ClassName,'Received JSON: '+jsonObject.ToJSON(false));
              Result := true;
              exit;
            end else begin
              TLog.NewLog(lterror,ClassName,'Invalid JSON class: '+jsonData.ClassName+' json: '+TBytesToString(PartialBuffer));
            End;
          Finally
            jsonData.Free; // Memory leak on 1.5.0
          end;
        end else begin
          TLog.NewLog(lterror,ClassName,Format('Read %d bytes but no valid JSON inside: %s',[last_bytes_read,TBytesToString(PartialBuffer)]));
        end;
      end;
      sleep(1);
      if Assigned(SenderThread) then continue := Not SenderThread.Terminated
      else continue := true;
    end;
    if (length(FReceivedBuffer)>0) And (DeleteBufferOnExit) then begin
      TLog.NewLog(lterror,ClassName,AnsiString( Format('Deleting %d bytes from buffer after waiting %d milis: %s',[length(FReceivedBuffer),MaxWaitMiliseconds,TBytesToString(FReceivedBuffer)])));
      SetLength(FReceivedBuffer,0);
    end;
  finally
    FlushBufferPendingMessages(false,0);
    FLockProcessBuffer.Release;
  end;
end;

function TJSONRPCTcpIpClient.GetNewId: Cardinal;
begin
  FLockReceivedBuffer.Acquire;
  try
    inc(FLastId);
    Result := FLastId;
  finally
    FLockReceivedBuffer.Release;
  end;
end;

procedure TJSONRPCTcpIpClient.SendJSONRPCErrorResponse(const id: Variant; const error: String);
Var response : TPCJSONObject;
  stream : TMemoryStream;
  b : Byte;
begin
  TLog.NewLog(lterror,ClassName,'Sending Error JSON RPC id ('+VarToStr(id)+') : '+error);
  response := TPCJSONObject.Create;
  Try
    response.GetAsVariant('result').Value := Null;
    response.GetAsVariant('error').Value := error;
    response.GetAsVariant('id').Value := id;
    stream := TMemoryStream.Create;
    try
      response.SaveToStream(stream);
      b := 13;
      stream.Write(b,1);
      b := 10;
      stream.Write(b,1);
      stream.Position := 0;
      WriteBufferToSend(stream);
    finally
      stream.Free;
    end;
  Finally
    response.Free;
  End;
end;

procedure TJSONRPCTcpIpClient.SendJSONRPCMethod(const method: String; params: TPCJSONList; const id: Variant);
Var json : TPCJSONObject;
  stream : TMemoryStream;
  b : Byte;
  P : PPendingResponseMessage;
begin
  json := TPCJSONObject.Create;
  Try
    json.GetAsVariant('id').Value := id;
    json.GetAsVariant('method').Value := method;
    if Assigned(params) then begin
      If params is TPCJSONObject then begin
        json.GetAsArray('params').GetAsObject(0).Assign(params);
      end else if params is TPCJSONArray then begin
        json.GetAsArray('params').Assign(params);
      end;
    end;
    if (Not VarIsNull(id)) then begin
      new(P);
      P^.id:=id;
      P^.sendDateTime:=Now;
      P^.maxDateTime:=Now + encodetime(0,0,30,0);
      P^.method:=method;
      FPendingResponseMessages.Add(P);
    end;
    TLog.NewLog(ltDebug,Classname,'Sending JSON: '+json.ToJSON(false));
    stream := TMemoryStream.Create;
    try
      json.SaveToStream(stream);
      b := 13;
      stream.Write(b,1);
      b := 10;
      stream.Write(b,1);
      stream.Position := 0;
      WriteBufferToSend(stream);
    finally
      stream.Free;
    end;
  Finally
    json.Free;
  End;
end;

function TJSONRPCTcpIpClient.SendJSONRPCMethodAndWait(const method: String; params: TPCJSONList; MaxWaitMiliseconds: Int64; resultObject : TPCJSONObject; processEventOnInvalid : TProcessJSONObjectEvent = Nil) : Boolean;
Var nId : Cardinal;
  tc : TTickCount;
  json : TPCJSONObject;
  rm : String;
begin
  Result := false;
  FLockProcessBuffer.Acquire;
  try
    nId := GetNewId;
    SendJSONRPCMethod(method,params,nId);
    tc := TPlatform.GetTickCount;
    json := TPCJSONObject.Create;
    Try
      repeat
        If DoProcessBuffer(nil,MaxWaitMiliseconds,true,rm,json) then begin
          If json.AsCardinal('id',0)=nId then begin
            resultObject.Assign(json);
            Result := true;
          end else begin
            TLog.NewLog(ltdebug,classname,'Received a unexpected JSON while waiting for response Id:'+inttostr(nId)+' Received:'+json.ToJSON(false));
            If Assigned(processEventOnInvalid) then begin
              TLog.NewLog(ltdebug,classname,'Sending to process unexpected JSON:'+json.ToJSON(false));
              processEventOnInvalid(json,rm);
            end else TLog.NewLog(lterror,Classname,'Lost JSON message! '+json.ToJSON(false));
          end;
        end;
      until (Result) Or (TPlatform.GetElapsedMilliseconds(tc)>MaxWaitMiliseconds);
    finally
      json.free;
    end;
    if (Not Result) then begin
      TLog.NewLog(lterror,classname,'Not received a JSON response Id:'+inttostr(nId)+' for method:'+method);
    end;
  finally
    FLockProcessBuffer.Release;
  end;
end;

procedure TJSONRPCTcpIpClient.SendJSONRPCResponse(result: TPCJSONObject; const id: Variant);
Var response : TPCJSONObject;
  stream : TMemoryStream;
  b : Byte;
begin
  response := TPCJSONObject.Create;
  Try
    If Assigned(Result) then response.GetAsObject('result').Assign(result)
    else response.GetAsVariant('result').Value:=null;
    response.GetAsVariant('error').Value := Null;
    response.GetAsVariant('id').Value := id;
    stream := TMemoryStream.Create;
    try
      response.SaveToStream(stream);
      b := 13;
      stream.Write(b,1);
      b := 10;
      stream.Write(b,1);
      stream.Position := 0;
      WriteBufferToSend(stream);
    finally
      stream.Free;
    end;
  Finally
    response.Free;
  End;
end;

{ TPoolMiningServer }

Const CT_WAIT_SECONDS_BEFORE_SEND_NEW_JOB = 10;
  CT_MAX_SECONDS_BETWEEN_JOBS = 30; // 1.5.3 Will send new job to miner (with updated timestamp)
  CT_MAX_BUFFER_JOBS = 10; // 1.5.3 Will buffer last 10 jobs sent to miner

Type
  TPoolJob = Record
    OperationsComp : TPCOperationsComp;
    SentDateTime : TDateTime;
    SentMinTimestamp : Cardinal;
  End;
  PPoolJob = ^TPoolJob;

procedure TPoolMiningServer.CaptureNewJobAndSendToMiners;
Var P, PToDelete : PPoolJob;
  i : Integer;
  l : TList<Pointer>;
  l2 : TList<TNetTcpIpClient>;
  doAdd : Boolean;
  params : TPCJSONObject;
  OpB : TOperationBlock;
  LLockedMempool : TPCOperationsComp;
begin
  if Not Active then exit;
  if FClientsCount<=0 then exit;
  doAdd := false;
  P := Nil;
  l := FPoolJobs.LockList;
  Try
    if l.count=0 then doAdd := true
    else begin
      P := l[l.Count-1];
      LLockedMempool := FNodeNotifyEvents.Node.LockMempoolRead;
      try
        if (Not TBaseType.Equals(LLockedMempool.OperationsHashTree.HashTree,P^.OperationsComp.OperationsHashTree.HashTree)) then begin
          doAdd := (P^.SentDateTime + EncodeTime(0,0,CT_WAIT_SECONDS_BEFORE_SEND_NEW_JOB,0)) < Now;
        end else begin
          // No new operations waiting to be sent, but to prevent "old time mining", we will send new job with time:
          doAdd := ((P^.SentDateTime + EncodeTime(0,0,CT_MAX_SECONDS_BETWEEN_JOBS,0)) < Now);
        end;
      finally
        FNodeNotifyEvents.Node.UnlockMempoolRead;
      end;
    end;
    if doAdd then begin
      New(P);
      P^.SentDateTime := now;
      P^.SentMinTimestamp := TNetData.NetData.NetworkAdjustedTime.GetAdjustedTime;
      if (P^.SentMinTimestamp<FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp) then begin
        P^.SentMinTimestamp := FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp;
      end;
      FillMinerOperations;
      P^.OperationsComp := TPCOperationsComp.Create(Nil);
      P^.OperationsComp.CopyFrom(FMinerOperations);
      P^.OperationsComp.AccountKey := FMinerAccountKey;
      P^.OperationsComp.BlockPayload := FMinerPayload;
      P^.OperationsComp.timestamp := P^.SentMinTimestamp; // Best practices 1.5.3
      OpB := P^.OperationsComp.OperationBlock;
      if (OpB.block<>0) And (OpB.block <> (FNodeNotifyEvents.Node.Bank.LastOperationBlock.block+1)) then begin
        // A new block is generated meanwhile ... do not include
        TLog.NewLog(ltDebug,ClassName,'Generated a new block meanwhile ... '+TPCOperationsComp.OperationBlockToText(OpB)+'<>'+TPCOperationsComp.OperationBlockToText(FNodeNotifyEvents.Node.Bank.LastOperationBlock));
        P^.OperationsComp.Free;
        Dispose(P);
        P := Nil;
      end else begin
        i := l.Add(P);
        {$IFDEF HIGHLOG}TLog.NewLog(ltDebug,ClassName,'Added new job '+IntToStr(i+1)+'/'+IntToStr(l.Count));{$ENDIF}
      end;
    end;
    // Clean buffer jobs
    while (l.Count>CT_MAX_BUFFER_JOBS) do begin
      PToDelete := l[0]; // Index 0 is oldest sent job
      l.Delete(0);
      PToDelete^.OperationsComp.free;
      Dispose(PToDelete);
      TLog.NewLog(ltDebug,ClassName,'Deleted Job 1 from buffer, now count:'+inttostr(l.Count));
    end;
  if (doAdd) And (Assigned(P)) then begin
    params := TPCJSONObject.Create;
    Try
      l2 := NetTcpIpClientsLock;
      Try
        for i := 0 to l2.Count - 1 do begin
          if Not Active then exit;
          SendJobToMiner(P^.OperationsComp,l2[i] as TJSONRPCTcpIpClient,false,null);
        end;
        {$IFDEF HIGHLOG}TLog.NewLog(ltDebug,ClassName,'Sending job to miners: '+TPCOperationsComp.OperationBlockToText(P^.OperationsComp.OperationBlock)+' Cache blocks:'+Inttostr(l2.Count));{$ENDIF}
      Finally
        NetTcpIpClientsUnlock;
      End;
    Finally
      params.Free;
    End;
  end;
  Finally
    FPoolJobs.UnlockList;
  End;
end;

procedure TPoolMiningServer.ClearPoolJobs;
Var P : PPoolJob;
  i : Integer;
  l : TList<Pointer>;
begin
  l := FPoolJobs.LockList;
  Try
    for i := l.Count - 1 downto 0 do begin
      P := l[i];
      l.Delete(i);
      P^.OperationsComp.Free;
      Dispose(P);
    end;
    l.Clear;
  Finally
    FPoolJobs.UnlockList;
  End;
end;

constructor TPoolMiningServer.Create;
begin
  inherited;
  FOnMiningServerNewBlockFound := Nil;
  FIncomingsCounter := 0;
  FClientsWins := 0;
  FClientsCount := 0;
  MaxConnections:=1000;
  NetTcpIpClientClass := TJSONRPCTcpIpClient;
  FNodeNotifyEvents := TNodeNotifyEvents.Create(Nil);
  FNodeNotifyEvents.OnBlocksChanged := OnNodeNewBlock;
  FNodeNotifyEvents.OnOperationsChanged := OnNodeOperationsChanged;
  FNodeNotifyEvents.Node := TNode.Node;
  FMinerOperations := TPCOperationsComp.Create(FNodeNotifyEvents.Node.Bank);
  FMinerAccountKey := CT_TECDSA_Public_Nul;
  FMinerPayload := Nil;
  FPoolJobs := TPCThreadList<Pointer>.Create('TPoolMiningServer_PoolJobs');
  FPoolThread := TPoolMiningServerThread.Create(Self);
  FMax0FeeOperationsPerBlock := CT_MAX_0_fee_operations_per_block_by_miner;
  FMaxOperationsPerBlock := CT_MAX_Operations_per_block_by_miner;
end;

destructor TPoolMiningServer.Destroy;
begin
  FPoolThread.Terminate;
  FPoolThread.WaitFor;
  FreeAndNil(FPoolThread);
  FNodeNotifyEvents.Node := Nil;
  FNodeNotifyEvents.OnBlocksChanged := Nil;
  FNodeNotifyEvents.OnOperationsChanged := Nil;
  FreeAndNil(FMinerOperations);
  FreeAndNil(FNodeNotifyEvents);
  ClearPoolJobs;
  FreeAndNil(FPoolJobs);
  inherited;
end;

procedure TPoolMiningServer.DoProcessJSON(json: TPCJSONObject; ResponseMethod : String; Client : TJSONRPCTcpIpClient);
Var method : String;
    params : TPCJSONArray;
    id_value : Variant;
    i : Integer;
  response_result : TPCJSONObject;
  LDigest : TRawBytes;
begin
  If ResponseMethod<>'' then begin
    method := ResponseMethod;
    params := json.GetAsArray('result');
  end else begin
    method := json.AsString('method','');
    params := json.GetAsArray('params');
  end;
  i := json.IndexOfName('id');
  if i<0 then begin
    id_value := Null;
  end else begin
    id_value := json.GetAsVariant('id').Value;
  end;
  if method=CT_PoolMining_Method_STATUS then begin
    response_result := TPCJSONObject.Create;
    Try
      response_result.GetAsVariant('block').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.block;
      response_result.GetAsVariant('account_key').Value := TCrypto.ToHexaString( TAccountComp.AccountKey2RawString(FNodeNotifyEvents.Node.Bank.LastOperationBlock.account_key) );
      response_result.GetAsVariant('reward').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.reward;
      response_result.GetAsVariant('fee').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.fee;
      response_result.GetAsVariant('p_version').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.protocol_version;
      response_result.GetAsVariant('p_available').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.protocol_available;
      response_result.GetAsVariant('timestamp').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp;
      response_result.GetAsVariant('target').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.compact_target;
      response_result.GetAsVariant('nonce').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.nonce;
      response_result.GetAsVariant('payload').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.block_payload );
      response_result.GetAsVariant('initial_sbh').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.initial_safe_box_hash );
      response_result.GetAsVariant('operations_hash').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.operations_hash );
      response_result.GetAsVariant('pow').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.proof_of_work );
      response_result.GetAsVariant('previous_pow').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.previous_proof_of_work );
      Client.SendJSONRPCResponse(response_result,id_value);
    Finally
      response_result.Free;
    End;
  end else if method=CT_PoolMining_Method_MINER_NOTIFY then begin
    SendJobToMiner(Nil,Client,true,id_value);
  end else if method=CT_PoolMining_Method_MINER_SUBMIT then begin
    // Try to submit a PoW
    if params.Count=1 then MinerSubmit(Client,params.GetAsObject(0),id_value)
    else begin
      Client.SendJSONRPCErrorResponse(id_value,'params must be 1-count JSON array');
      TLog.NewLog(lterror,ClassName,'Invalid params array of method '+method);
    end;
  end else if (method=CT_PoolMining_Method_MINER_RANDOMHASH) or (method=CT_PoolMining_Method_MINER_RANDOMHASH2) then begin
    //
    if params.Count<>1 then begin
      Client.SendJSONRPCErrorResponse(id_value,'params must be 1-count JSON array');
    end else if (params.Items[0] is TPCJSONVariantValue) then begin
      // Check the digest:
      if Not TCrypto.HexaToRaw( params.GetAsVariant(0).AsString(''), LDigest ) then begin
        Client.SendJSONRPCErrorResponse(id_value,'array does not contain an hexastring');
      end else begin
        response_result := TPCJSONObject.Create;
        Try
          response_result.GetAsVariant('digest').Value := LDigest.ToHexaString;
          if (method=CT_PoolMining_Method_MINER_RANDOMHASH) then begin
            // RandomHash 1 algo
            response_result.GetAsVariant('hash').Value := TCrypto.DoRandomHash(LDigest).ToHexaString;
            response_result.GetAsVariant('algo').Value := 'rh';
          end else begin
            // RandomHash 2 algo
            response_result.GetAsVariant('hash').Value := TCrypto.DoRandomHash2(LDigest).ToHexaString;
            response_result.GetAsVariant('algo').Value := 'rh2';
          end;
          Client.SendJSONRPCResponse(response_result,id_value);
        Finally
          response_result.Free;
        End;
      end;
    end;
  end else begin
    // Invalid command
    if (not VarIsNull(id_value)) then begin
      Client.SendJSONRPCErrorResponse(id_value,'method not found: '+method);
    end;
  end;
end;

procedure TPoolMiningServer.FillMinerOperations;
var tree : TOperationsHashTree;
  Procedure DoAdd(Const Op : TPCOperation; checkDuplicate : Boolean);
  Begin
    if checkDuplicate then begin
      if tree.IndexOfOperation(Op)>=0 then exit;
    end;
    if (Op is TOpRecoverFounds) then begin
      if Not TAccountComp.EqualAccountKeys( TOpRecoverFounds(Op).Data.new_accountkey , FMinerAccountKey ) then begin
        TLog.NewLog(lterror,ClassName,'Adding a OpRecoverFounds operation from another public key: '+Op.ToString);
      end;
    end;
    tree.AddOperationToHashTree(Op);
  End;
Var i,j : Integer;
  LLockedMempool : TPCOperationsComp;
  op : TPCOperation;
  errors : String;
begin
  LLockedMempool := FNodeNotifyEvents.Node.LockMempoolRead;
  Try
    FMinerOperations.Lock;
    Try
      tree := TOperationsHashTree.Create;
      try
        if (Not (TPCOperationsComp.EqualsOperationBlock(FMinerOperations.OperationBlock,LLockedMempool.OperationBlock))) then begin
          FMinerOperations.Clear(true);
          CheckMinerRecover(LLockedMempool);
          if LLockedMempool.Count>0 then begin
            // First round: Select with fee > 0
            i := 0;
            while (tree.OperationsCount<MaxOperationsPerBlock) And (i<LLockedMempool.OperationsHashTree.OperationsCount) do begin
              op := LLockedMempool.OperationsHashTree.GetOperation(i);
              if op.OperationFee>0 then begin
                DoAdd(op,false);
              end;
              inc(i);
            end;
            // Second round: Allow fee = 0
            j := 0;
            i := 0;
            while (tree.OperationsCount<MaxOperationsPerBlock) And (i<LLockedMempool.OperationsHashTree.OperationsCount) And (j<Max0FeeOperationsPerBlock) do begin
              op := LLockedMempool.OperationsHashTree.GetOperation(i);
              if op.OperationFee=0 then begin
                DoAdd(op,True);
                inc(j);
              end;
              inc(i);
            end;
            // Add operations:
            i := FMinerOperations.AddOperations(tree,errors);
            if (i<>tree.OperationsCount) Or (i<>LLockedMempool.OperationsHashTree.OperationsCount) then begin
              TLog.NewLog(ltDebug,ClassName,Format('Cannot add all operations! Master:%d Selected:%d Added:%d - Errors: %s',
                [LLockedMempool.OperationsHashTree.OperationsCount,tree.OperationsCount,i,errors]));
            end;
          end else begin
            FMinerOperations.CopyFrom(LLockedMempool);
          end;
          //
          {$IFDEF HIGHLOG}TLog.NewLog(ltdebug,ClassName,Format('New miner operations:%d Hash:%s %s',
            [FMinerOperations.OperationsHashTree.OperationsCount,TCrypto.ToHexaString(FMinerOperations.OperationsHashTree.HashTree),TCrypto.ToHexaString(FMinerOperations.OperationBlock.operations_hash)]));{$ENDIF}
        end else begin
          TLog.NewLog(ltDebug,ClassName,Format('No need to change Miner buffer. Operations:%d',[FMinerOperations.OperationsHashTree.OperationsCount]));
        end;
      finally
        tree.Free;
      end;
    Finally
      FMinerOperations.Unlock;
    end;
  Finally
    FNodeNotifyEvents.Node.UnlockMempoolRead;
  End;
end;

function TPoolMiningServer.MinerSubmit(Client: TJSONRPCTcpIpClient; params: TPCJSONObject; const id : Variant): Boolean;
Var s : String;
  nbOperations : TPCOperationsComp;
  errors, sJobInfo : String;
  json : TPCJSONObject;
  p1,p2,p3 : TRawBytes;
  P : PPoolJob;
  i : Integer;
  l : TList<Pointer>;
  _payloadHexa : AnsiString;
  _payloadRaw : TRawBytes;
  _timestamp, _nOnce : Cardinal;
  _targetPoW : TRawBytes;
begin
  { Miner params must submit:
    - "payload" as an Hexadecimal
    - "timestamp" as an unsigned integer 32 bits
    - "nonce" as an unsigned integer 32 bits
    If payload length is < Node payload then error
    If Node payload is not included in first bytes of payload then error
    If timestamp is not valid then error
    If calculated PoW does not match valid PoW then error
    If all ok... congrats!!! }
  Result := false;
  sJobInfo := '';
  // Must chek on previous sent jobs
  nbOperations := Nil;
  Try
    _payloadHexa := params.AsString('payload','');
    _payloadRaw := TCrypto.HexaToRaw(_payloadHexa);
    if Length(FMinerPayload)>0 then begin
      if (Not TBaseType.Equals(copy(_payloadRaw,Low(_payloadRaw),length(FMinerPayload)),FMinerPayload)) then begin
        Client.SendJSONRPCErrorResponse(id,'Invalid payload ('+_payloadHexa+'). Need start with: '+TCrypto.ToHexaString(FMinerPayload));
        exit;
      end;
    end;
    _timestamp := params.AsCardinal('timestamp',0);
    _nOnce := params.AsCardinal('nonce',0);
    l := FPoolJobs.LockList;
    Try
      i := l.Count-1;
      while (i>=0) And (Not Assigned(nbOperations)) do begin
        sJobInfo := 'Miner job '+IntToStr(i+1)+'/'+IntToStr(l.Count);
        P := l[i];
        // Best practices: Only will accept a solution if timestamp >= sent timestamp for this job (1.5.3)
        If (P^.SentMinTimestamp<=_timestamp) then begin

          _targetPow := TPascalCoinProtocol.TargetFromCompact( P^.OperationsComp.OperationBlock.compact_target, P^.OperationsComp.OperationBlock.protocol_version );

          P^.OperationsComp.Update_And_RecalcPOW(_nOnce,_timestamp,_payloadRaw);
          if (TBaseType.BinStrComp(P^.OperationsComp.OperationBlock.proof_of_work,_targetPoW)<=0) then begin
            // Candidate!
            nbOperations := TPCOperationsComp.Create(Nil);
            nbOperations.bank := FNodeNotifyEvents.Node.Bank;
            nbOperations.CopyFrom(P^.OperationsComp);
            nbOperations.AccountKey := MinerAccountKey;
            TLog.NewLog(ltInfo,ClassName,sJobInfo+' - Found a solution for block '+IntToStr(nbOperations.OperationBlock.block));
          end else TLog.NewLog(lterror,ClassName,sJobInfo+Format(' Calculated Pow > Min PoW ->  %s > %s',
            [TCrypto.ToHexaString(P^.OperationsComp.OperationBlock.proof_of_work),TCrypto.ToHexaString(_targetPoW)]));
        end else begin
          TLog.NewLog(lterror,ClassName,sJobInfo+Format(' Timestamp %d < MinTimestamp %d',[_timestamp,P^.SentMinTimestamp]));
        end;
        dec(i);
      end;
    Finally
      FPoolJobs.UnlockList;
    End;
    if Assigned(nbOperations) then begin
      If FNodeNotifyEvents.Node.AddNewBlockChain(nil,nbOperations,errors) then begin
        // CONGRATS !!!
        json := TPCJSONObject.Create;
        try
          json.GetAsVariant('block').Value := FNodeNotifyEvents.Node.Bank.LastOperationBlock.block;
          json.GetAsVariant('pow').Value := TCrypto.ToHexaString( FNodeNotifyEvents.Node.Bank.LastOperationBlock.proof_of_work );
          json.GetAsVariant('payload').Value := nbOperations.BlockPayload.ToString;
          json.GetAsVariant('timestamp').Value := nbOperations.timestamp;
          json.GetAsVariant('nonce').Value := nbOperations.nonce;
          inc(FClientsWins);
          Client.SendJSONRPCResponse(json,id);
        finally
          json.Free;
        end;
        if Assigned(FOnMiningServerNewBlockFound) then FOnMiningServerNewBlockFound(Self);
      end else begin
        Client.SendJSONRPCErrorResponse(id,'Error: '+errors+' executing '+sJobInfo+' payload:'+TCrypto.ToHexaString(nbOperations.BlockPayload)+' timestamp:'+InttoStr(nbOperations.timestamp)+' nonce:'+IntToStr(nbOperations.nonce));
      end;
    end else begin
      Client.SendJSONRPCErrorResponse(id,'Error: No valid job found with these values! (Perhaps prior block job or old job) payload:'+_payloadHexa+' timestamp:'+InttoStr(_timestamp)+' nonce:'+IntToStr(_nonce));
    end;
  Finally
    if Assigned(nbOperations) then nbOperations.Free;
  End;
end;

// Looks for accounts to recover, adds up to 100 recoverFounds Operations to nbOperations
procedure TPoolMiningServer.CheckMinerRecover(nbOperations: TPCOperationsComp);
var
  LAccOrd: TAccountsOrderedByUpdatedBlock;
  LAccount: TAccount;
  LRecoverAccounts: TList<TAccount>;
  LIndexKey, LRecIndex, LRecoverAccountsCount: Integer;
begin
  LIndexKey := 0;
  LRecoverAccountsCount := 0;
  LRecoverAccounts := TList<TAccount>.Create(); // make a list of RecoverAccounts
  nbOperations.Lock;
  try
    LAccOrd := nbOperations.bank.SafeBox.AccountsOrderedByUpdatedBlock; // Walk AccountsOrderedByUpdatedBlock, this keeps a list of the oldest accounts
    if Assigned(LAccOrd) then begin
      LAccount := CT_Account_NUL;
      if LAccOrd.First(LIndexKey) then begin
        LRecIndex := 0;
        LRecoverAccountsCount := LAccOrd.Count;
        while ((LRecIndex < LRecoverAccountsCount) and (LRecIndex < CT_MAX_0_fee_operations_per_block_by_miner)) do begin
          LAccount := FNodeNotifyEvents.Node.GetMempoolAccount(LIndexKey);
          if(TAccountComp.AccountCanRecover(LAccount, nbOperations.OperationBlock.block)) then begin // does the AccountCanRecover check, !locked, old enough, etc
            LRecoverAccounts.Add(LAccount);
          end else begin
            Break; // we could not recover this account, then we can never recover move recent accounts
          end;
          if Not LAccOrd.Next(LIndexKey) then Break;
          Inc(LRecIndex);
        end;
        nbOperations.AddMinerRecover(LRecoverAccounts,FMinerAccountKey);
      end;
    end;
  finally
    nbOperations.Unlock;
    LRecoverAccounts.Free; // destroy the list, operations have been added
  end;
end;

procedure TPoolMiningServer.OnNewIncommingConnection(Sender: TObject; Client: TNetTcpIpClient);
var bClient : TJSONRPCTcpIpClient;
  jsonobj : TPCJSONObject;
  doDelete : Boolean;
  rmethod : String;
begin
  inherited;
  inc(FClientsCount);
  Try
    TLog.NewLog(ltinfo,ClassName,'New Mining Pool Connection: '+Client.ClientRemoteAddr);
    bClient := TJSONRPCTcpIpClient(Client);
    inc(FIncomingsCounter);
    SendJobToMiner(nil,bClient,false,null);
    while (Active) And (Client.Connected) do begin
      doDelete := bClient.LastReadTC+1000<TPlatform.GetTickCount;  // TODO: Protect GetTickCount overflow
      jsonobj := TPCJSONObject.Create;
      try
        if bClient.DoProcessBuffer(nil,1000,doDelete,rmethod,jsonobj) then begin
          DoProcessJSON(jsonobj,rmethod,bClient);
        end;
      finally
        jsonobj.free;
      end;
      sleep(1);
    end;
  Finally
    Dec(FClientsCount);
    TLog.NewLog(ltinfo,ClassName,'Finalizing Mining Pool Connection: '+Client.ClientRemoteAddr);
  End;
end;

procedure TPoolMiningServer.OnNodeNewBlock(Sender: TObject);
begin
  // Delete Jobs cache, because a new block was found prior to us
  ClearPoolJobs;
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.OnNodeOperationsChanged(Sender: TObject);
begin
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.SendJobToMiner(Operations: TPCOperationsComp; Client: TJSONRPCTcpIpClient; IsResponse : Boolean; idResponse : Variant);
var params : TPCJSONObject;
  ts : Cardinal;
Var P : PPoolJob;
  i,nJobs : Integer;
  l : TList<Pointer>;
begin
  if FClientsCount<=0 then exit;
  if (Not Assigned(Operations)) then begin
    P := Nil;
    l := FPoolJobs.LockList;
    Try
      if l.count>0 then P := l[l.Count-1] // The last
      else begin
        //TLog.NewLog(ltInfo,ClassName,'Creating new job for miner');
        New(P);
        P^.SentDateTime := now;
        P^.SentMinTimestamp := TNetData.NetData.NetworkAdjustedTime.GetAdjustedTime;
        if (P^.SentMinTimestamp<FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp) then begin
          P^.SentMinTimestamp := FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp;
        end;
        FillMinerOperations;
        P^.OperationsComp := TPCOperationsComp.Create(Nil);
        P^.OperationsComp.CopyFrom(FMinerOperations);
        P^.OperationsComp.AccountKey := FMinerAccountKey;
        P^.OperationsComp.BlockPayload := FMinerPayload;
        P^.OperationsComp.timestamp := P^.SentMinTimestamp; // Best practices 1.5.3
        if (P^.OperationsComp.OperationBlock.block<>0) And (P^.OperationsComp.OperationBlock.block <> (FNodeNotifyEvents.Node.Bank.LastOperationBlock.block+1)) then begin
          TLog.NewLog(ltError,ClassName,'ERROR DEV 20170228-2 '+TPCOperationsComp.OperationBlockToText(P^.OperationsComp.OperationBlock)+'<>'+TPCOperationsComp.OperationBlockToText(FNodeNotifyEvents.Node.Bank.LastOperationBlock));
          P^.OperationsComp.Free;
          Dispose(P);
          raise Exception.Create('ERROR DEV 20170228-2');
        end;
        l.Add(P);
      end;
    Finally
      FPoolJobs.UnlockList;
    End;
    Operations := P^.OperationsComp;
  end;
  l := FPoolJobs.LockList;
  Try
    nJobs := l.Count;
  Finally
    FPoolJobs.UnlockList;
  End;

  params := TPCJSONObject.Create;
  Try
    if Not Active then exit;
    params.GetAsVariant('block').Value := Operations.OperationBlock.block;
    params.GetAsVariant('version').Value := Operations.OperationBlock.protocol_version;
    params.GetAsVariant('part1').Value := TCrypto.ToHexaString( Operations.PoW_Digest_Part1 );
    params.GetAsVariant('payload_start').Value := TCrypto.ToHexaString( Operations.OperationBlock.block_payload );
    params.GetAsVariant('part3').Value := TCrypto.ToHexaString( Operations.PoW_Digest_Part3 );
    params.GetAsVariant('target').Value := Operations.OperationBlock.compact_target;
    params.GetAsVariant('target_pow').Value := TCrypto.ToHexaString(TPascalCoinProtocol.TargetFromCompact(Operations.OperationBlock.compact_target,Operations.OperationBlock.protocol_version));

    ts := TNetData.NetData.NetworkAdjustedTime.GetAdjustedTime;
    if (ts<FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp) then begin
      ts := FNodeNotifyEvents.Node.Bank.LastOperationBlock.timestamp;
    end;
    params.GetAsVariant('timestamp').Value := ts;

    if IsResponse then begin
      Client.SendJSONRPCResponse(params,idResponse);
    end else begin
      Client.SendJSONRPCMethod(CT_PoolMining_Method_MINER_NOTIFY,params,Null);
    end;

    TLog.NewLog(ltdebug,ClassName,
      Format('Sending job %d to miner - Block:%d Ops:%d Target:%s PayloadStart:%s',
      [nJobs,Operations.OperationBlock.block,Operations.Count,IntToHex(Operations.OperationBlock.compact_target,8),Operations.OperationBlock.block_payload.ToPrintable]));
  Finally
    params.Free;
  End;
end;

procedure TPoolMiningServer.SetActive(const Value: Boolean);
begin
  inherited;
  if (Not Value) then begin
    WaitUntilNetTcpIpClientsFinalized;
  end;
end;


procedure TPoolMiningServer.SetMax0FeeOperationsPerBlock(const Value: Integer);
begin
  if FMax0FeeOperationsPerBlock = Value then exit;
  if (Value<(CT_MAX_0_fee_operations_per_block_by_miner DIV 5)) Or (Value<1) then begin
    FMax0FeeOperationsPerBlock := (CT_MAX_0_fee_operations_per_block_by_miner DIV 5); // To prevent no 0 fee...
    if FMax0FeeOperationsPerBlock<1 then FMax0FeeOperationsPerBlock := 1; // For Testnet or low constant values...
    TLog.NewLog(ltError,ClassName,Format('Invalid max zero fee operations per block value %d, set to %d',[Value,FMax0FeeOperationsPerBlock]));
  end else FMax0FeeOperationsPerBlock := Value;
  TLog.NewLog(ltInfo,ClassName,Format('Updated max zero fee operations per block to %d',[FMax0FeeOperationsPerBlock]));
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.SetMaxOperationsPerBlock(const Value: Integer);
begin
  if FMaxOperationsPerBlock = Value then exit;
  if (Value<(CT_MAX_Operations_per_block_by_miner DIV 5)) Or (Value<1) then begin
    FMaxOperationsPerBlock := (CT_MAX_Operations_per_block_by_miner DIV 5); // To prevent very small blocks...
    if FMaxOperationsPerBlock<1 then FMaxOperationsPerBlock := 1; // For Testnet or low constant values...
    TLog.NewLog(ltError,ClassName,Format('Invalid max operations per block value %d, set to %d',[Value,FMaxOperationsPerBlock]));
  end else FMaxOperationsPerBlock := Value;
  TLog.NewLog(ltInfo,ClassName,Format('Updated max operations per block to %d',[FMaxOperationsPerBlock]));
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.SetMinerAccountKey(const Value: TAccountKey);
begin
  if TAccountComp.EqualAccountKeys(FMinerAccountKey,Value) then exit;
  FMinerAccountKey := Value;
  TLog.NewLog(ltdebug,ClassName,'Assigning Miner account key to: '+TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(Value)));
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.SetMinerPayload(const Value: TRawBytes);
begin
  FMinerPayload := Value;
  TLog.NewLog(ltdebug,ClassName,'Assigning Miner new Payload: '+TCrypto.ToHexaString(Value));
  CaptureNewJobAndSendToMiners;
end;

procedure TPoolMiningServer.UpdateAccountAndPayload(
  AMinerAccountKey: TAccountKey; AMinerPayload: TRawBytes);
begin
  FMinerAccountKey := AMinerAccountKey;
  TLog.NewLog(ltdebug,ClassName,'Assigning Miner account key to: '+TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(AMinerAccountKey)));
  FMinerPayload := AMinerPayload;
  TLog.NewLog(ltdebug,ClassName,'Assigning Miner new Payload: '+TCrypto.ToHexaString(AMinerPayload));
  CaptureNewJobAndSendToMiners;
end;

{ TPoolMinerClient }

constructor TPoolMinerClient.Create(AOwner: TComponent);
begin
  FMinerValuesForWork := CT_TMinerValuesForWork_NULL;
  FPoolType:=ptSolomine;
  FUserName:='';
  FPassword:='';
  FPoolFinalMinerName:=Nil;
  FStratum_Target_PoW:=Nil;
  FStratumAuthorized := False;
  FStratum_ExtraNOnce2_Size := 0;
  inherited;
end;

procedure TPoolMinerClient.DoOnConnect;
Var params : TPCJSONArray;
  resultObject : TPCJSONObject;
  s : String;
  raws : TRawBytes;
  i : Integer;
begin
  inherited DoOnConnect;
  If FPoolType=ptPoolSubscription then begin
    // Pool initialization
    params := TPCJSONArray.Create;
    resultObject := TPCJSONObject.Create;
    try
      If SendJSONRPCMethodAndWait(CT_PoolMining_Method_STRATUM_MINING_SUBSCRIBE,params,8000,resultObject,DoProcessJSONObject) then begin
        //
        DoProcessJSONObject(resultObject,CT_PoolMining_Method_STRATUM_MINING_SUBSCRIBE);
        //
        Sleep(100);
        //
        params.GetAsVariant(0).Value:=UserName;
        params.GetAsVariant(1).Value:=Password;
        If SendJSONRPCMethodAndWait(CT_PoolMining_Method_STRATUM_MINING_AUTHORIZE,params,8000,resultObject,DoProcessJSONObject) then begin
          DoProcessJSONObject(resultObject,CT_PoolMining_Method_STRATUM_MINING_AUTHORIZE);
          FStratumAuthorized := True;
        end else raise Exception.Create('Not response to "'+CT_PoolMining_Method_STRATUM_MINING_AUTHORIZE+'" method for user "'+UserName+'"');
      end else raise Exception.Create('Not response to "'+CT_PoolMining_Method_STRATUM_MINING_SUBSCRIBE+'" method for user "'+UserName+'"');
    finally
      resultObject.free;
      params.free;
    end;
  end;
end;

procedure TPoolMinerClient.DoProcessJSONObject(json: TPCJSONObject; ResponseMethod : String);
Var method : String;
    id_value : Variant;
    i : Integer;
  params_as_object,pobject : TPCJSONObject;
  params_as_array : TPCJSONArray;
  params : TPCJSONData;
  mvfw : TMinerValuesForWork;
  prev_pow,proposed_pow : TRawBytes;

  procedure StratumUpdatedDifficulty(ANewDifficultyValue : Double);
  var LBigNumDiff : TBigNum;
    LAuxPOW : TRawBytes;
    LHexa : String;
  begin
    LBigNumDiff := TBigNum.Create('00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
    try
      if (ANewDifficultyValue<=0) then Exit;

      if (ANewDifficultyValue<1) then begin
        LBigNumDiff.Multiply( Round(1000.0/ANewDifficultyValue) ).Divide( 1000 );
      end else begin
        LBigNumDiff.Multiply( Round(ANewDifficultyValue*1000.0) ).Divide( 1000 );
      end;
      LHexa := LBigNumDiff.HexaValue;
    finally
      LBigNumDiff.Free;
    end;
    while (LHexa.Length<64) do LHexa.Insert(0,'0');
    TCrypto.HexaToRaw( LHexa, LAuxPOW );
    if TBaseType.Equals(LAuxPOW,FStratum_Target_PoW) then Exit; // Nothing to update

    FStratum_Target_PoW := LAuxPOW;
    TLog.NewLog(ltInfo,ClassName,Format('Set Difficulty to %.6f -> Target PoW:%s %s',[ANewDifficultyValue,
      TPascalCoinProtocol.TargetToCompact(FStratum_Target_PoW,CT_PROTOCOL_4).ToHexString,
      FStratum_Target_PoW.ToHexaString]));
  end;

  procedure ExtractStratumMinerValuesFromWork(const AJobID, ADigestPart_1, ADigestPart_2, AStratumTime : String);
  var LMVFW : TMinerValuesForWork;
    LStream : TStream;
    LRaw : TRawBytes;
  begin
    LMVFW := CT_TMinerValuesForWork_NULL;
    // Extracting Miner Values From Work from Digest parts:
    if Not TCrypto.HexaToRaw( ADigestPart_1, LRaw) then begin
      TLog.NewLog(ltError,ClassName,Format('Digest Part 1 obtained is not Hexadecimal: "%s" length %d',[ADigestPart_1,Length(ADigestPart_1)]));
      Exit;
    end;
    if (Length(LRaw)<20) then begin
      TLog.NewLog(ltError,ClassName,Format('Digest Part 1 is too short: "%s" length %d',[ADigestPart_1,Length(ADigestPart_1)]));
      Exit;
    end;
    LMVFW.part1 := LRaw;
    if Not TCrypto.HexaToRaw(ADigestPart_2,LMVFW.part3) then begin
      TLog.NewLog(ltError,ClassName,Format('Digest Part 2 obtained is not Hexadecimal: "%s" length %d',[ADigestPart_2,Length(ADigestPart_2)]));
      Exit;
    end;
    LStream := TMemoryStream.Create;
    try
      LStream.WriteBuffer( LRaw[0], Length(LRaw) );
      LStream.Position := 0;
      // Block number is stored as a Little Endian on first 4 bytes (8 hexa chars)
      LStream.Read(LMVFW.block,4);

      if LMVFW.block=0 then Exit;

      // Latest 8 bytes are:
      // 2 - protocol_version
      // 2 - protocol_available
      // 4 - target
      LStream.Seek(-8,soFromEnd);
      LStream.Read(LMVFW.version,2);
      LStream.Seek(2,soFromCurrent);
      LStream.Read(LMVFW.target,4);
      LMVFW.jobid := AJobID;
    finally
      LStream.Free;
    end;
    // Capture timestamp
    LMVFW.timestamp := StrToIntDef('$'+AStratumTime,0);
    //
    MinerValuesForWork := LMVFW;
  end;

  procedure ExtractStratumMinerValuesFromWorkFromParams;
  var i : Integer;
  begin
    if Not Assigned(params_as_array) then Exit;
    i := params_as_array.Count - 9;
    if (i<0) or (i>1) then Exit;

    if (i=1) then begin
      // Extract difficulty from position 0
      StratumUpdatedDifficulty( params_as_array.GetAsVariant(0).AsDouble(1) );
    end;

    // STRATUM
    ExtractStratumMinerValuesFromWork(
      params_as_array.GetAsVariant(0 + i).AsString(''),
      params_as_array.GetAsVariant(2 + i).AsString(''),
      params_as_array.GetAsVariant(3 + i).AsString(''),
      params_as_array.GetAsVariant(7 + i).AsString('')
    );
  end;


begin
  params := Nil;
  params_as_object := Nil;
  params_as_array := Nil;
  if (ResponseMethod<>'') then begin
    method := ResponseMethod;
    i := json.IndexOfName('result');
    if (i>=0) then begin
      params := json.Items[i];
    end;
    {$IFDEF HIGHLOG}TLog.NewLog(ltinfo,classname,'Received response method:'+ResponseMethod+' JSON:'+json.ToJSON(false));{$ENDIF}
  end else begin
    method := json.AsString('method','');
  end;
  i := json.IndexOfName('params');
  if (i>=0) then begin
    params := json.Items[i];
  end;
  If Assigned(params) then begin
    if (params is TPCJSONNameValue) then begin
      if (TPCJSONNameValue(params).Value is TPCJSONObject) then params_as_object := TPCJSONObject(TPCJSONNameValue(params).Value)
      else if (TPCJSONNameValue(params).Value is TPCJSONArray) then params_as_array := TPCJSONArray(TPCJSONNameValue(params).Value);
    end else if (params is TPCJSONArray) then params_as_array := TPCJSONArray(params)
    else if (params is TPCJSONObject) then params_as_object := TPCJSONObject(params)
  end;
  i := json.IndexOfName('id');
  if i<0 then begin
    id_value := Null;
  end else begin
    id_value := json.GetAsVariant('id').Value;
  end;
  if method=CT_PoolMining_Method_MINER_NOTIFY then begin
    If assigned(params_as_array) then pobject := params_as_array.GetAsObject(0)
    else pobject := params_as_object;
    if assigned(pobject) then begin
      mvfw := CT_TMinerValuesForWork_NULL;
      mvfw.block := pobject.AsInteger('block',0);
      mvfw.version := pobject.AsInteger('version',0);
      mvfw.part1 := TCrypto.HexaToRaw(pobject.AsString('part1',''));
      mvfw.payload_start := TCrypto.HexaToRaw(pobject.AsString('payload_start',''));
      mvfw.part3 := TCrypto.HexaToRaw(pobject.AsString('part3',''));
      mvfw.target := pobject.AsInteger('target',0);
      mvfw.timestamp := pobject.AsInteger('timestamp',0);
      mvfw.part1 := TCrypto.HexaToRaw(pobject.AsString('part1',''));
      mvfw.target_pow := TCrypto.HexaToRaw(pobject.AsString('target_pow',''));
      If FPoolType=ptPoolSubscription then begin
        mvfw.jobid:=pobject.AsString('jobid','');
      end;
      if (Not VarIsNull(id_value)) And (ResponseMethod='') then begin
        SendJSONRPCResponse(pobject,id_value);
      end;
      MinerValuesForWork := mvfw;
    end else TLog.NewLog(ltError,ClassName,'method '+method+' without JSON object '+params.ToJSON(false));
  end else if (method=CT_PoolMining_Method_MINER_SUBMIT) then begin
    //
  end else if (method=CT_PoolMining_Method_STRATUM_MINING_AUTHORIZE) And
    (PoolType=ptPoolSubscription) And (Assigned(params_as_array)) then begin
    //
    FStratumAuthorized := True;
    ExtractStratumMinerValuesFromWorkFromParams;
  end else if (method=CT_PoolMining_Method_STRATUM_MINING_SUBSCRIBE) And
    (PoolType=ptPoolSubscription) And (Assigned(params_as_array)) then begin
    // STRATUM
    // {"id":2,"result":[[["mining.notify","00000000000000000000000000000000"]],"303030303030303030",8],"error":null}
    // Explained at: https://slushpool.com/help/stratum-protocol/
    // params[0] -> Subscription details
    // params[1] -> Extranonce1
    // params[2] -> Extranonce2_size
    FPoolFinalMinerName := TCrypto.HexaToRaw( params_as_array.GetAsVariant(1).AsString('') );
    FStratum_ExtraNOnce2_Size := params_as_array.GetAsVariant(2).AsInteger(0);
  end else if (method=CT_PoolMining_Method_STRATUM_MINING_SET_DIFFICULTY) And
    (PoolType=ptPoolSubscription) And (Assigned(params_as_array)) then begin
    // STRATUM
    // {"id":null,"method":"mining.set_difficulty","params":[0.0000152588]}
    StratumUpdatedDifficulty( params_as_array.GetAsVariant(0).AsDouble(1) );

  end else if (method=CT_PoolMining_Method_STRATUM_MINING_NOTIFY) And
    (PoolType=ptPoolSubscription) And (Assigned(params_as_array)) then begin
    ExtractStratumMinerValuesFromWorkFromParams;
  end else if (method=CT_PoolMining_Method_STRATUM_MINING_SUBMIT) And
    (PoolType=ptPoolSubscription) then begin
    // Response to a mining submit event
    if (json.GetAsVariant('error').AsBoolean(False)) then begin
      TLog.NewLog(lterror,ClassName,Format('Invalid SHARE %s',[method,json.ToJSON(False)]));
    end;
  end else begin
    TLog.NewLog(lterror,ClassName,Format('Unknown method received "%s": %s',[method,json.ToJSON(False)]));
  end;
end;

procedure TPoolMinerClient.SetMinerValuesForWork(const Value: TMinerValuesForWork);
Var _t : Cardinal;
  _t_pow : TRawBytes;
begin
  FMinerValuesForWork := Value;
  If Length(FStratum_Target_PoW)>0 then begin
    FMinerValuesForWork.target:=TPascalCoinProtocol.TargetToCompact(FStratum_Target_PoW,FMinerValuesForWork.version);
    FMinerValuesForWork.target_pow:=TPascalCoinProtocol.TargetFromCompact(FMinerValuesForWork.target,FMinerValuesForWork.version);
  end else begin
    // Check that target and target_pow are equal!
    _t_pow := TPascalCoinProtocol.TargetFromCompact(FMinerValuesForWork.target,FMinerValuesForWork.version);
    if (length(FMinerValuesForWork.target_pow)=32) then begin
      _t := TPascalCoinProtocol.TargetToCompact(FMinerValuesForWork.target_pow,FMinerValuesForWork.version);
      if (FMinerValuesForWork.target<TPascalCoinProtocol.MinimumTarget(FMinerValuesForWork.version)) then begin
        // target has no valid value... assigning compact_target!
        FMinerValuesForWork.target:=TPascalCoinProtocol.TargetToCompact(_t_pow,FMinerValuesForWork.version);
      end else if (Not TBaseType.Equals(_t_pow,FMinerValuesForWork.target_pow)) Or (_t<>FMinerValuesForWork.target) then begin
        TLog.NewLog(ltError,Classname,'Received bad values for target and target_pow!');
        If (FMinerValuesForWork.target<TPascalCoinProtocol.MinimumTarget(FMinerValuesForWork.version)) then begin
          FMinerValuesForWork.target_pow:=TPascalCoinProtocol.TargetFromCompact(FMinerValuesForWork.target,FMinerValuesForWork.version);
        end else begin
          FMinerValuesForWork.target:=TPascalCoinProtocol.TargetToCompact(_t_pow,FMinerValuesForWork.version);
        end;
      end;
    end else begin
      if (FMinerValuesForWork.target>=TPascalCoinProtocol.MinimumTarget(FMinerValuesForWork.version)) then begin
        // target_pow has no value... assigning target!
        FMinerValuesForWork.target_pow:=TPascalCoinProtocol.TargetFromCompact(FMinerValuesForWork.target,FMinerValuesForWork.version);
      end else begin
        // Invalid target and compact_target
        FMinerValuesForWork.target := CT_TMinerValuesForWork_NULL.target;
        FMinerValuesForWork.target_pow := CT_TMinerValuesForWork_NULL.target_pow;
      end;
    end;
  end;
  If (FPoolType=ptPoolSubscription) And (Length(FPoolFinalMinerName)>0) then begin
    FMinerValuesForWork.payload_start:=FPoolFinalMinerName;
    FMinerValuesForWork.extraNOnce2_Size:=FStratum_ExtraNOnce2_Size;
    FMinerValuesForWork.extraNOnce2_Used:=Nil;
  end;
  if Assigned(FOnMinerMustChangeValues) then FOnMinerMustChangeValues(Self);
end;

procedure TPoolMinerClient.SubmitBlockFound(Const MinerValuesToGenerateBlock : TMinerValuesForWork; const Payload: TRawBytes; Timestamp, NOnce: Cardinal; const AObtainedPoW : TRawBytes);
Var json : TPCJSONObject;
  LnOnceAsSignedInt : Int32;
  LArrJSON : TPCJSONArray;
begin
  LnOnceAsSignedInt := NOnce;
  If FPoolType=ptPoolSubscription then begin
    LArrJSON := TPCJSONArray.Create;
    Try
      LArrJSON.GetAsVariant(0).Value := UserName;
      LArrJSON.GetAsVariant(1).Value := MinerValuesToGenerateBlock.jobid;
      LArrJSON.GetAsVariant(2).Value := MinerValuesToGenerateBlock.extraNOnce2_Used.ToHexaString; //  Payload.ToHexaString;// + '1234567812345678'; // '1234567812345678'; //Payload.ToHexaString;
      LArrJSON.GetAsVariant(3).Value := IntToHex(Timestamp,8);
      LArrJSON.GetAsVariant(4).Value := IntToHex(LnOnceAsSignedInt,8);
      SendJSONRPCMethod(CT_PoolMining_Method_STRATUM_MINING_SUBMIT,LArrJSON,GetNewId);
      TLog.NewLog(ltInfo,ClassName,Format('SHARE for job %s block %d Time %s NOnce %s ExtraNOnce2 %s PoW %s',
       [MinerValuesToGenerateBlock.jobid,
        MinerValuesToGenerateBlock.block,
        IntToHex(Timestamp,8),
        IntToHex(LnOnceAsSignedInt,8),
        MinerValuesToGenerateBlock.extraNOnce2_Used.ToHexaString,
        AObtainedPoW.ToHexaString]));
    Finally
      LArrJSON.Free;
    End;
  end else begin
    json := TPCJSONObject.Create;
    Try
      If FPoolType=ptPoolSubscription then begin
        json.GetAsVariant('jobid').Value := MinerValuesToGenerateBlock.jobid;
      end;
      json.GetAsVariant('payload').Value := TCrypto.ToHexaString(Payload);
      json.GetAsVariant('timestamp').Value := Timestamp;
      json.GetAsVariant('nonce').Value := LnOnceAsSignedInt;
      SendJSONRPCMethod(CT_PoolMining_Method_MINER_SUBMIT,json,GetNewId);
      TLog.NewLog(ltInfo,ClassName,Format('FOUND SOLUTION for block %d Time %s NOnce %s Payload %s PoW %s',
       [
        MinerValuesToGenerateBlock.block,
        IntToHex(Timestamp,8),
        IntToHex(LnOnceAsSignedInt,8),
        Payload.ToHexaString,
        AObtainedPoW.ToHexaString]));
    Finally
      json.Free;
    End;
  end;
end;

{ TPoolMiningServerThread }

procedure TPoolMiningServerThread.BCExecute;
Var i : Integer;
begin
  i := 0;
  Repeat
    Sleep(100);
    inc(i);
    if (not terminated) And ((i mod 10)=0) then begin
      Try
        FPoolMiningServer.CaptureNewJobAndSendToMiners;
      Except
        On E:Exception do begin
          TLog.NewLog(ltError,ClassName,'Error ('+E.ClassName+') Capturing job for miners: '+E.Message );
        end;
      End;
    end;
  Until terminated;
end;

constructor TPoolMiningServerThread.Create(APoolMiningServer: TPoolMiningServer);
begin
  FPoolMiningServer := APoolMiningServer;
  inherited Create(false);
end;

destructor TPoolMiningServerThread.Destroy;
begin

  inherited;
end;

end.
