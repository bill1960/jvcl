unit MainFrm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, JvPrvwDoc, ComCtrls, StdCtrls, ExtCtrls, Menus, JvRichEdit;

type
  TfrmMain = class(TForm)
    Panel1: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Edit1: TEdit;
    udCols: TUpDown;
    Edit2: TEdit;
    udRows: TUpDown;
    Edit3: TEdit;
    udShadowWidth: TUpDown;
    Label4: TLabel;
    Edit4: TEdit;
    udZoom: TUpDown;
    PrinterSetupDialog1: TPrinterSetupDialog;
    cbPreview: TComboBox;
    Label5: TLabel;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Open1: TMenuItem;
    N1: TMenuItem;
    Printer1: TMenuItem;
    N2: TMenuItem;
    Exit1: TMenuItem;
    View1: TMenuItem;
    First1: TMenuItem;
    Previous1: TMenuItem;
    Next1: TMenuItem;
    Last1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    Options1: TMenuItem;
    mnuMargins: TMenuItem;
    PageControl1: TPageControl;
    tabPreview: TTabSheet;
    tabOriginal: TTabSheet;
    OpenDialog1: TOpenDialog;
    reOriginal: TJvRichEdit;
    PrintDialog1: TPrintDialog;
    Print1: TMenuItem;
    Label6: TLabel;
    cbScaleMode: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure udColsClick(Sender: TObject; Button: TUDBtnType);
    procedure udRowsClick(Sender: TObject; Button: TUDBtnType);
    procedure udShadowWidthClick(Sender: TObject; Button: TUDBtnType);
    procedure udZoomClick(Sender: TObject; Button: TUDBtnType);
    procedure cbPreviewChange(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure Printer1Click(Sender: TObject);
    procedure mnuMarginsClick(Sender: TObject);
    procedure First1Click(Sender: TObject);
    procedure Previous1Click(Sender: TObject);
    procedure Next1Click(Sender: TObject);
    procedure Last1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Print1Click(Sender: TObject);
    procedure cbScaleModeChange(Sender: TObject);
  private
    procedure OpenFile(const Filename: string);
    procedure DoChange(Sender: TObject);
    { Private declarations }
  public
    { Public declarations }
    pd: TJvPreviewDoc;
  end;

  // NB! Implements very simple wordwrap (doesn't always work)!
  TJvStringsPreviewRenderer = class(TObject)
  private
    FStrings: TStrings;
    FPreview: TJvPreviewDoc;
    FFinished: boolean;
    FCurrentRow: integer;
    procedure CreatePreview;
    procedure DoAddPage(Sender: TObject; PageIndex: integer;
      Canvas: TCanvas; PageRect, PrintRect: TRect; var NeedMorePages: boolean);
  public
    constructor Create(Preview: TJvPreviewDoc; Strings: TStrings);
    destructor Destroy; override;
    property Finished: boolean read FFinished;
  end;

  TJvRTFRenderer = class(TObject)
  private
    FFinished: boolean;
    FLastChar: integer;
    FRE: TRichEdit;
    FPreview: TJvPreviewDoc;
    procedure DoAddPage(Sender: TObject; PageIndex: integer;
      Canvas: TCanvas; PageRect, PrintRect: TRect; var NeedMorePages: boolean);
    procedure CreatePreview;
  public
    constructor Create(Preview: TJvPreviewDoc; RichEdit: TRichEdit);
    property Finished: boolean read FFinished;
  end;

var
  frmMain: TfrmMain;

implementation
uses
  RichEdit, Printers;
  
{$R *.dfm}

type
  // a class that implements the IJvPrinter interface
  TJvPrinter = class(TInterfacedObject, IUnknown, IJvPrinter)
  private
    FPrinter: TPrinter;
  public
    constructor Create(APrinter: TPrinter);
    procedure BeginDoc;
    procedure EndDoc;
    function GetAborted: Boolean;
    function GetCanvas: TCanvas;
    function GetPageHeight: Integer;
    function GetPageWidth: Integer;
    function GetPrinting: Boolean;
    procedure NewPage;
    function GetTitle: string;
    procedure SetTitle(const Value: string);
  end;

  { TJvStringsPreviewRenderer }

constructor TJvStringsPreviewRenderer.Create(Preview: TJvPreviewDoc;
  Strings: TStrings);
begin
  inherited Create;
  FPreview := Preview;
  FStrings := Strings;
  CreatePreview;
end;

procedure TJvStringsPreviewRenderer.DoAddPage(Sender: TObject; PageIndex: integer; Canvas: TCanvas;
  PageRect, PrintRect: TRect; var NeedMorePages: boolean);
var i, IncValue: integer; ARect: TRect; tm: TTextMetric; S: string;
begin
  if not FFinished then
  begin
    Canvas.Font.Name := 'Verdana';
    Canvas.Font.Size := 10;
    ARect := PrintRect;

    GetTextMetrics(Canvas.Handle, tm);
    IncValue := Canvas.TextHeight('Wq') + tm.tmInternalLeading + tm.tmExternalLeading;
    ARect.Bottom := ARect.Top + IncValue;
    for i := FCurrentRow to FStrings.Count - 1 do
    begin
      ARect.Right := PrintRect.Right;
      S := FStrings[i];
      IncValue := DrawText(Canvas.Handle, PChar(S), Length(S), ARect, DT_CALCRECT or DT_NOPREFIX or DT_EXPANDTABS or DT_WORDBREAK or DT_LEFT or DT_TOP);
      if ARect.Right > PrintRect.Right then
      begin
        ARect.Right := PrintRect.Right; // reset and jsut force a line break in the middle (not fail proof!)
        S := Copy(S, 1, Length(S) div 2) + #13#10 +
          Copy(S, Length(S) div 2 + 1, Length(S));
        IncValue := DrawText(Canvas.Handle, PChar(S), Length(S), ARect, DT_CALCRECT or DT_NOPREFIX or DT_EXPANDTABS or DT_WORDBREAK or DT_LEFT or DT_TOP);
      end;
      if ARect.Bottom > PrintRect.Bottom then
      begin
        FPreview.Add; // New Page
        FCurrentRow := i;
        NeedMorePages := true;
        Exit;
      end;
      DrawText(Canvas.Handle, PChar(S), Length(S), ARect, DT_NOPREFIX or DT_EXPANDTABS or DT_WORDBREAK or DT_LEFT or DT_TOP);
      OffsetRect(ARect, 0, IncValue);
    end;
  end;
  FFinished := true;
end;

procedure TJvStringsPreviewRenderer.CreatePreview;
begin
  FPreview.Clear;
  FPreview.OnAddPage := DoAddPage;
  FCurrentRow := 0;
  if FStrings.Count > 0 then
    FPreview.Add
  else
    FFinished := true;
end;

destructor TJvStringsPreviewRenderer.Destroy;
begin
  //  FStrings.Free;
  inherited;
end;

{ TJvRTFRenderer }

constructor TJvRTFRenderer.Create(Preview: TJvPreviewDoc;
  RichEdit: TRichEdit);
begin
  inherited Create;
  FRE := RichEdit;
  FPreview := Preview;
  CreatePreview;
end;

procedure TJvRTFRenderer.CreatePreview;
begin
  if FRE.Lines.Count > 0 then
  begin
    FLastChar := 0;
    FPreview.BeginUpdate;
    try
      FPreview.Clear;
      FPreview.OnAddPage := DoAddPage;
      FPreview.Add; // this will call OnAddPage that will call Add until we are finished
    finally
      FPreview.EndUpdate;
    end;
  end
  else
    FFinished := true;
end;

// this code was almost entirely stolen from TRichEdit.Print
procedure TJvRTFRenderer.DoAddPage(Sender: TObject; PageIndex: integer;
  Canvas: TCanvas; PageRect, PrintRect: TRect; var NeedMorePages: boolean);
var
  Range: TFormatRange;
  OutDC: HDC;
  MaxLen, LogX, LogY, OldMap: Integer;
begin
  if not Finished then
  begin
    FillChar(Range, SizeOf(TFormatRange), 0);
    OutDC := Canvas.Handle;
    Range.hdc := OutDC;
    Range.hdcTarget := OutDC;
    LogX := GetDeviceCaps(OutDC, LOGPIXELSX);
    LogY := GetDeviceCaps(OutDC, LOGPIXELSY);
    if IsRectEmpty(FRE.PageRect) then
    begin
      Range.rc.right := (PrintRect.Right - PrintRect.Left) * 1440 div LogX;
      Range.rc.bottom := (PrintRect.Bottom - PrintRect.Top) * 1440 div LogY;
    end
    else
    begin
      Range.rc.left := FRE.PageRect.Left * 1440 div LogX;
      Range.rc.top := FRE.PageRect.Top * 1440 div LogY;
      Range.rc.right := FRE.PageRect.Right * 1440 div LogX;
      Range.rc.bottom := FRE.PageRect.Bottom * 1440 div LogY;
    end;
    Range.rcPage := Range.rc;
    MaxLen := FRE.GetTextLen;
    Range.chrg.cpMax := -1;

    // ensure the output DC is in text map mode
    OldMap := SetMapMode(Range.hdc, MM_TEXT);
    try
      SendMessage(FRE.Handle, EM_FORMATRANGE, 0, 0); // flush buffer

      Range.chrg.cpMin := FLastChar;
      FLastChar := SendMessage(FRE.Handle, EM_FORMATRANGE, 1, Longint(@Range));
      FFinished := (FLastChar >= MaxLen) or (FLastChar = -1);
      NeedMorePages := not FFinished;
      SendMessage(FRE.Handle, EM_FORMATRANGE, 0, 0); // flush buffer
    finally
      SetMapMode(OutDC, OldMap);
    end;
    Exit;
  end;
  //  FFinished := true;
end;

{ TJvPrinter }

procedure TJvPrinter.BeginDoc;
begin
  FPrinter.BeginDoc;
end;

constructor TJvPrinter.Create(APrinter: TPrinter);
begin
  Assert(APrinter <> nil, '');
  inherited Create;
  FPrinter := APrinter;
end;

procedure TJvPrinter.EndDoc;
begin
  FPrinter.EndDoc;
end;

function TJvPrinter.GetAborted: Boolean;
begin
  Result := FPrinter.Aborted;
end;

function TJvPrinter.GetCanvas: TCanvas;
begin
  Result := FPrinter.Canvas;
end;

function TJvPrinter.GetPageHeight: Integer;
begin
  Result := FPrinter.PageHeight;
end;

function TJvPrinter.GetPageWidth: Integer;
begin
  Result := FPrinter.PageWidth;
end;

function TJvPrinter.GetPrinting: Boolean;
begin
  Result := FPrinter.Printing;
end;

function TJvPrinter.GetTitle: string;
begin
  Result := FPrinter.Title;
end;

procedure TJvPrinter.NewPage;
begin
  FPrinter.NewPage;
end;

procedure TJvPrinter.SetTitle(const Value: string);
begin
  FPrinter.Title := Value;
end;

procedure TfrmMain.Print1Click(Sender: TObject);
var jp: TJvPrinter;
begin
  PrintDialog1.PrintRange := prAllPages;
  if pd.PageCount < 1 then
    PrintDialog1.Options := PrintDialog1.Options - [poPageNums]
  else
  begin
    PrintDialog1.Options := PrintDialog1.Options + [poPageNums];
    PrintDialog1.FromPage := 1;
    PrintDialog1.ToPage := pd.PageCount;
  end;
  if PrintDialog1.Execute then
  begin
    jp := TJvPrinter.Create(Printer);
    try
      if PrintDialog1.PrintRange = prPageNums then
        pd.PrintRange(jp, PrintDialog1.FromPage - 1, PrintDialog1.ToPage - 1, PrintDialog1.Copies, PrintDialog1.Collate)
      else
        pd.PrintRange(jp, 0, -1, PrintDialog1.Copies, PrintDialog1.Collate)
    finally
      jp.Free;
    end;
  end;
end;

function Max(Val1, Val2: integer): integer;
begin
  Result := Val1;
  if Val2 > Val1 then
    Result := Val2;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  pd := TJvPreviewDoc.Create(self);
  pd.Parent := tabPreview;
  pd.Align := alClient;
  pd.TabStop := true;
  pd.BeginUpdate;
  pd.OnChange := DoChange;
  try
    pd.Options.DrawMargins := mnuMargins.Checked;
    pd.Options.Rows := udRows.Position;
    pd.Options.Cols := udCols.Position;
    pd.Options.Shadow.Offset := udShadowWidth.Position;
    pd.Options.Scale := udZoom.Position;

    cbPreview.ItemIndex := 1; // printer
    cbPreviewChange(nil);
    cbScaleMode.ItemIndex := 0; // full page
    cbScaleModeChange(nil);

    // set 0.5 inch margin
    pd.DeviceInfo.OffsetLeft := Max(pd.DeviceInfo.InchToXPx(0.5),pd.DeviceInfo.OffsetLeft);
    pd.DeviceInfo.OffsetRight := Max(pd.DeviceInfo.InchToXPx(0.5),pd.DeviceInfo.OffsetRight);
    pd.DeviceInfo.OffsetTop := Max(pd.DeviceInfo.InchToYPx(0.5),pd.DeviceInfo.OffsetTop);
    pd.DeviceInfo.OffsetBottom := Max(pd.DeviceInfo.InchToYPx(0.5),pd.DeviceInfo.OffsetBottom);
  finally
    pd.EndUpdate;
  end;
end;

procedure TfrmMain.DoChange(Sender: TObject);
begin
  udCols.Position := pd.Options.Cols;
  udRows.Position := pd.Options.Rows;
  udShadowWidth.Position := pd.Options.Shadow.Offset;
  udZoom.Position := pd.Options.Scale;
  mnuMargins.Checked := pd.Options.DrawMargins;
  cbScaleMode.ItemIndex := Ord(pd.Options.ScaleMode);
  Caption := Format('%s: - (%d pages)',
    [ExtractFilename(OpenDialog1.Filename), pd.PageCount]);
end;

procedure TfrmMain.udColsClick(Sender: TObject; Button: TUDBtnType);
begin
  pd.Options.Cols := udCols.Position;
  udCols.Position := pd.Options.Cols;
end;

procedure TfrmMain.udRowsClick(Sender: TObject; Button: TUDBtnType);
begin
  pd.Options.Rows := udRows.Position;
  udRows.Position := pd.Options.Rows;
end;

procedure TfrmMain.udShadowWidthClick(Sender: TObject; Button: TUDBtnType);
begin
  pd.Options.Shadow.Offset := udShadowWidth.Position;
  udShadowWidth.Position := pd.Options.Shadow.Offset;
end;

procedure TfrmMain.udZoomClick(Sender: TObject; Button: TUDBtnType);
begin
  pd.Options.Scale := udZoom.Position;
  udZoom.Position := pd.Options.Scale;
end;

procedure TfrmMain.cbPreviewChange(Sender: TObject);
begin
  case cbPreview.ItemIndex of
    0:
      pd.DeviceInfo.ReferenceHandle := 0; // reset to default (screen)
    1:
      pd.DeviceInfo.ReferenceHandle := Printer.Handle;
  end;
  if FileExists(OpenDialog1.Filename) then
    OpenFile(OpenDialog1.Filename);
end;

procedure TfrmMain.OpenFile(const Filename: string);
begin
  reOriginal.Lines.LoadFromFile(OpenDialog1.Filename);
  Screen.Cursor := crHourGlass;
  with TJvRTFRenderer.Create(pd, reOriginal) do
  try
    while not Finished do ;
//      Application.ProcessMessages;
  finally
    Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.Open1Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenFile(OpenDialog1.Filename);
end;

procedure TfrmMain.Exit1Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.Printer1Click(Sender: TObject);
begin
  PrinterSetupDialog1.Execute;
  cbPreviewChange(nil);
end;

procedure TfrmMain.mnuMarginsClick(Sender: TObject);
begin
  mnuMargins.Checked := not mnuMargins.Checked;
  pd.Options.DrawMargins := mnuMargins.Checked;
end;

procedure TfrmMain.First1Click(Sender: TObject);
begin
  pd.SelectedPage := 0;
end;

procedure TfrmMain.Previous1Click(Sender: TObject);
begin
  pd.SelectedPage := pd.SelectedPage - 1;
end;

procedure TfrmMain.Next1Click(Sender: TObject);
begin
  pd.SelectedPage := pd.SelectedPage + 1;
end;

procedure TfrmMain.Last1Click(Sender: TObject);
begin
  pd.SelectedPage := pd.PageCount - 1;
end;

procedure TfrmMain.About1Click(Sender: TObject);
begin
  ShowMessage('JvPreviewDocument Demo');
end;

procedure TfrmMain.cbScaleModeChange(Sender: TObject);
begin
  pd.Options.ScaleMode := TJvPreviewScaleMode(cbScaleMode.ItemIndex);
  cbScaleMode.ItemIndex := Ord(pd.Options.ScaleMode);
end;

end.

