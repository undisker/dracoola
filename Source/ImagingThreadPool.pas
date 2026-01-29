{*******************************************************}
{                                                       }
{       Imaging Thread Pool Unit                        }
{       FreePascal-only multi-threading support         }
{                                                       }
{       Provides thread pool for parallel image         }
{       processing operations                           }
{                                                       }
{*******************************************************}

unit ImagingThreadPool;

{$I ImagingOptions.inc}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { Task procedure types }
  TImagingTaskProc = procedure(TaskIndex, TaskCount: Integer; UserData: Pointer);
  TImagingTaskMethod = procedure(TaskIndex, TaskCount: Integer) of object;

  { Forward declaration }
  TImagingThreadPool = class;

  { Worker thread class }
  TImagingWorkerThread = class(TThread)
  private
    FPool: TImagingThreadPool;
    FTaskProc: TImagingTaskProc;
    FTaskMethod: TImagingTaskMethod;
    FTaskIndex: Integer;
    FTaskCount: Integer;
    FUserData: Pointer;
    FWorkEvent: TEvent;
    FDoneEvent: TEvent;
    FUseMethod: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TImagingThreadPool);
    destructor Destroy; override;
    procedure AssignTask(TaskProc: TImagingTaskProc; TaskIndex, TaskCount: Integer;
      UserData: Pointer); overload;
    procedure AssignTask(TaskMethod: TImagingTaskMethod; TaskIndex, TaskCount: Integer); overload;
    procedure StartWork;
    procedure WaitForCompletion;
  end;

  { Thread pool for parallel processing }
  TImagingThreadPool = class
  private
    FWorkers: array of TImagingWorkerThread;
    FWorkerCount: Integer;
    FShutdown: Boolean;
    FLock: TCriticalSection;
  public
    constructor Create(WorkerCount: Integer = 0);
    destructor Destroy; override;

    { Execute a task in parallel using procedure callback }
    procedure ParallelFor(StartIndex, EndIndex: Integer;
      TaskProc: TImagingTaskProc; UserData: Pointer = nil);

    { Execute a task in parallel using method callback }
    procedure ParallelForMethod(StartIndex, EndIndex: Integer;
      TaskMethod: TImagingTaskMethod);

    { Execute tile-based processing }
    procedure ExecuteTiles(ImageWidth, ImageHeight, TileSize: Integer;
      TileProc: TImagingTaskProc; UserData: Pointer = nil);

    { Properties }
    property WorkerCount: Integer read FWorkerCount;
    property Shutdown: Boolean read FShutdown;
  end;

{ Global thread pool instance }
var
  GlobalThreadPool: TImagingThreadPool = nil;

{ Get optimal thread count based on CPU cores }
function GetOptimalThreadCount: Integer;

{ Initialize global thread pool (called automatically if IMAGING_MULTITHREADED) }
procedure InitGlobalThreadPool(WorkerCount: Integer = 0);

{ Finalize global thread pool }
procedure FinalizeGlobalThreadPool;

{ Check if parallel processing is beneficial for given pixel count }
function ShouldUseParallel(PixelCount: Integer): Boolean;

const
  { Minimum pixels before enabling parallel processing }
  IMAGING_MIN_PARALLEL_SIZE = 65536;  // 256x256 pixels

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

{$IFDEF UNIX}
uses
  {$IFDEF DARWIN}
  ctypes,
  {$ENDIF}
  BaseUnix, Unix;
{$ENDIF}

{ Get CPU core count }

function GetCpuCoreCount: Integer;
{$IFDEF MSWINDOWS}
var
  SysInfo: TSystemInfo;
begin
  GetSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
  if Result < 1 then
    Result := 1;
end;
{$ELSE}
{$IFDEF UNIX}
begin
  Result := sysconf(_SC_NPROCESSORS_ONLN);
  if Result < 1 then
    Result := 1;
end;
{$ELSE}
begin
  Result := 1;
end;
{$ENDIF}
{$ENDIF}

function GetOptimalThreadCount: Integer;
begin
  Result := GetCpuCoreCount;
  // Leave one core free for system/UI
  if Result > 2 then
    Dec(Result);
  // Cap at reasonable maximum
  if Result > 16 then
    Result := 16;
end;

function ShouldUseParallel(PixelCount: Integer): Boolean;
begin
  Result := (GlobalThreadPool <> nil) and
            (GlobalThreadPool.WorkerCount > 1) and
            (PixelCount >= IMAGING_MIN_PARALLEL_SIZE);
end;

{ TImagingWorkerThread }

constructor TImagingWorkerThread.Create(APool: TImagingThreadPool);
begin
  inherited Create(True); // Create suspended
  FPool := APool;
  FWorkEvent := TEvent.Create(nil, False, False, '');
  FDoneEvent := TEvent.Create(nil, False, False, '');
  FTaskProc := nil;
  FTaskMethod := nil;
  FTaskIndex := 0;
  FTaskCount := 0;
  FUserData := nil;
  FUseMethod := False;
  FreeOnTerminate := False;
end;

destructor TImagingWorkerThread.Destroy;
begin
  FWorkEvent.Free;
  FDoneEvent.Free;
  inherited Destroy;
end;

procedure TImagingWorkerThread.Execute;
begin
  while not Terminated do
  begin
    // Wait for work
    if FWorkEvent.WaitFor(100) = wrSignaled then
    begin
      if Terminated then
        Break;

      // Execute the task
      try
        if FUseMethod then
        begin
          if Assigned(FTaskMethod) then
            FTaskMethod(FTaskIndex, FTaskCount);
        end
        else
        begin
          if Assigned(FTaskProc) then
            FTaskProc(FTaskIndex, FTaskCount, FUserData);
        end;
      except
        // Swallow exceptions in worker threads
        // TODO: Could add error reporting mechanism
      end;

      // Signal completion
      FDoneEvent.SetEvent;
    end;
  end;
end;

procedure TImagingWorkerThread.AssignTask(TaskProc: TImagingTaskProc;
  TaskIndex, TaskCount: Integer; UserData: Pointer);
begin
  FTaskProc := TaskProc;
  FTaskMethod := nil;
  FTaskIndex := TaskIndex;
  FTaskCount := TaskCount;
  FUserData := UserData;
  FUseMethod := False;
end;

procedure TImagingWorkerThread.AssignTask(TaskMethod: TImagingTaskMethod;
  TaskIndex, TaskCount: Integer);
begin
  FTaskProc := nil;
  FTaskMethod := TaskMethod;
  FTaskIndex := TaskIndex;
  FTaskCount := TaskCount;
  FUserData := nil;
  FUseMethod := True;
end;

procedure TImagingWorkerThread.StartWork;
begin
  FWorkEvent.SetEvent;
end;

procedure TImagingWorkerThread.WaitForCompletion;
begin
  FDoneEvent.WaitFor(INFINITE);
end;

{ TImagingThreadPool }

constructor TImagingThreadPool.Create(WorkerCount: Integer);
var
  I: Integer;
begin
  inherited Create;
  FLock := SyncObjs.TCriticalSection.Create;
  FShutdown := False;

  // Determine worker count
  if WorkerCount <= 0 then
    FWorkerCount := GetOptimalThreadCount
  else
    FWorkerCount := WorkerCount;

  // Create worker threads
  SetLength(FWorkers, FWorkerCount);
  for I := 0 to FWorkerCount - 1 do
  begin
    FWorkers[I] := TImagingWorkerThread.Create(Self);
    FWorkers[I].Start;
  end;
end;

destructor TImagingThreadPool.Destroy;
var
  I: Integer;
begin
  FShutdown := True;

  // Terminate and free all workers
  for I := 0 to High(FWorkers) do
  begin
    FWorkers[I].Terminate;
    FWorkers[I].FWorkEvent.SetEvent; // Wake up if waiting
  end;

  for I := 0 to High(FWorkers) do
  begin
    FWorkers[I].WaitFor;
    FWorkers[I].Free;
  end;

  SetLength(FWorkers, 0);
  FLock.Free;
  inherited Destroy;
end;

procedure TImagingThreadPool.ParallelFor(StartIndex, EndIndex: Integer;
  TaskProc: TImagingTaskProc; UserData: Pointer);
var
  I: Integer;
  TaskCount: Integer;
  TasksPerWorker: Integer;
  Remainder: Integer;
  CurrentTask: Integer;
  WorkersUsed: Integer;
begin
  TaskCount := EndIndex - StartIndex + 1;

  if TaskCount <= 0 then
    Exit;

  // For small task counts, just run sequentially
  if (TaskCount = 1) or (FWorkerCount <= 1) then
  begin
    for I := StartIndex to EndIndex do
      TaskProc(I, TaskCount, UserData);
    Exit;
  end;

  FLock.Enter;
  try
    // Calculate task distribution
    WorkersUsed := FWorkerCount;
    if WorkersUsed > TaskCount then
      WorkersUsed := TaskCount;

    TasksPerWorker := TaskCount div WorkersUsed;
    Remainder := TaskCount mod WorkersUsed;

    CurrentTask := StartIndex;

    // Assign tasks to workers
    for I := 0 to WorkersUsed - 1 do
    begin
      FWorkers[I].AssignTask(TaskProc, CurrentTask, TaskCount, UserData);

      // Move to next task range
      Inc(CurrentTask, TasksPerWorker);
      if I < Remainder then
        Inc(CurrentTask);
    end;

    // Start all workers
    for I := 0 to WorkersUsed - 1 do
      FWorkers[I].StartWork;

    // Wait for all workers to complete
    for I := 0 to WorkersUsed - 1 do
      FWorkers[I].WaitForCompletion;

  finally
    FLock.Leave;
  end;
end;

procedure TImagingThreadPool.ParallelForMethod(StartIndex, EndIndex: Integer;
  TaskMethod: TImagingTaskMethod);
var
  I: Integer;
  TaskCount: Integer;
  WorkersUsed: Integer;
begin
  TaskCount := EndIndex - StartIndex + 1;

  if TaskCount <= 0 then
    Exit;

  if (TaskCount = 1) or (FWorkerCount <= 1) then
  begin
    for I := StartIndex to EndIndex do
      TaskMethod(I, TaskCount);
    Exit;
  end;

  FLock.Enter;
  try
    WorkersUsed := FWorkerCount;
    if WorkersUsed > TaskCount then
      WorkersUsed := TaskCount;

    // Assign tasks
    for I := 0 to WorkersUsed - 1 do
      FWorkers[I].AssignTask(TaskMethod, StartIndex + I, TaskCount);

    // Start workers
    for I := 0 to WorkersUsed - 1 do
      FWorkers[I].StartWork;

    // Wait for completion
    for I := 0 to WorkersUsed - 1 do
      FWorkers[I].WaitForCompletion;

  finally
    FLock.Leave;
  end;
end;

procedure TImagingThreadPool.ExecuteTiles(ImageWidth, ImageHeight, TileSize: Integer;
  TileProc: TImagingTaskProc; UserData: Pointer);
var
  TilesX, TilesY: Integer;
  TotalTiles: Integer;
begin
  // Calculate number of tiles
  TilesX := (ImageWidth + TileSize - 1) div TileSize;
  TilesY := (ImageHeight + TileSize - 1) div TileSize;
  TotalTiles := TilesX * TilesY;

  if TotalTiles > 0 then
    ParallelFor(0, TotalTiles - 1, TileProc, UserData);
end;

{ Global functions }

procedure InitGlobalThreadPool(WorkerCount: Integer);
begin
  if GlobalThreadPool = nil then
    GlobalThreadPool := TImagingThreadPool.Create(WorkerCount);
end;

procedure FinalizeGlobalThreadPool;
begin
  if GlobalThreadPool <> nil then
  begin
    GlobalThreadPool.Free;
    GlobalThreadPool := nil;
  end;
end;

{$IFDEF IMAGING_MULTITHREADED}
initialization
  InitGlobalThreadPool;

finalization
  FinalizeGlobalThreadPool;
{$ENDIF}

end.
