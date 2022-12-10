unit MainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Ani, System.Rtti, FMX.Grid,
  FMX.Layouts, FMX.Objects,
  Generics.Collections, Generics.Defaults;

type
  TRowData = Record
    id:Word;
    Name:string;
    Date:string;
    FDate:Integer;
    Previews:boolean;
    Size:Integer;
  end;

  TGetFolderSizeThread = class(TThread)
  private
    findex:word;
    fdir:string;
    fsize:Int64;
    procedure Done;
  protected
    procedure Execute; override;
  public
    constructor Create(index: integer; Dir:string);
  end;

  TCustomColumn = class(TStringColumn)
  protected
    procedure DefaultDrawCell(const Canvas: TCanvas; const Bounds: TRectF; const Row: Integer;
      const Value: TValue; const State: TGridDrawStates); override;
  public
    MaxValue:Int64;
  end;

  TMainForm = class(TForm)
    CatalogList: TGrid;
    StringColumn1: TStringColumn;
    StringColumn2: TStringColumn;
    StringColumn3: TStringColumn;
    PreviewsColumn: TImageColumn;
    StatusBar: TStatusBar;
    ProgressBar: TProgressBar;
    procedure CatalogListHeaderClick(Column: TColumn);
    procedure FormCreate(Sender: TObject);
    procedure CatalogListGetValue(Sender: TObject; const Col, Row: Integer;
      var Value: TValue);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure CatalogListSelectCell(Sender: TObject; const ACol, ARow: Integer;
      var CanSelect: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
    SizeColumn:TCustomColumn;
    LastSortColumn:integer;
    CatalogDir:string;
    CatalogListData:TList<TRowData>;
    preview_bmp:TBitmap;
  end;

var
  MainForm: TMainForm;

procedure LoadCatalogList;

implementation

{$R *.fmx}

uses FolderUtilsUnit;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
CatalogListData.Free;
preview_bmp.Free;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  RStream: TResourceStream;
begin
RStream:=TResourceStream.Create(HInstance,'preview_img',RT_RCDATA);
preview_bmp:=TBitmap.Create;
preview_bmp.LoadFromStream(RStream);
RStream.Free;
CatalogListData:=TList<TRowData>.Create;
CatalogList.RowCount:=0;
with TThread.CreateAnonymousThread(
  procedure
  begin
  LoadCatalogList;
  end) do begin
    FreeOnTerminate:=true;
    Start;
  end;
LastSortColumn:=-1;
SizeColumn:=TCustomColumn.Create(CatalogList);
SizeColumn.Header:='Preview size';
CatalogList.AddObject(SizeColumn);
end;

function IsValidDate(s:string):Integer;
var
  dt:TDateTime;
begin
try
  dt:=StrToDateTime(s);
  result:=Trunc(dt);
except
  Result:=-1;
end;
end;

procedure ProgressBarHide;
begin
MainForm.ProgressBar.Visible:=false;
end;

procedure LoadCatalogList;
var
  SearchRec: TSearchRec;
  FileName:string;
  SL: TStringList;
  s:string;
  i:Word;
  fdate:integer;
  row:TRowData;
begin
  FileName := '*.*';
  SL:=TStringList.Create;
  SL.Delimiter:='_';
  MainForm.CatalogDir:='D:/lightroom catalogs';
  MainForm.CatalogList.RowCount:=0;

  if FindFirst(MainForm.CatalogDir+'/*.*', faDirectory	,SearchRec) = 0 then
  repeat
    if ((SearchRec.Attr and faDirectory) = SearchRec.Attr)and(SearchRec.Name<>'.')and(SearchRec.Name<>'..') then
    begin
      row.id:=MainForm.CatalogListData.Count;
      row.Name:=SearchRec.Name;
      row.Previews:=DirectoryExists(MainForm.CatalogDir+'/'+SearchRec.Name+'/'+ SearchRec.Name+' Previews.lrdata');
      row.size:=0;
      if row.Previews then begin
          TGetFolderSizeThread.Create(row.id,MainForm.CatalogDir+'/'+SearchRec.Name+'/'+ SearchRec.Name+' Previews.lrdata');
        end;
      SL.DelimitedText:=Trim(SearchRec.Name);
      row.Date:='';
      row.FDate:=0;
      if (SL.Count>3) then begin
        for i:=0 to SL.Count-4 do begin
          s:=SL.Strings[i]+'.'+SL.Strings[i+1]+'.'+SL.Strings[i+2];
          fdate:=IsValidDate(s);
          if fdate>0 then begin
            row.Date:=s;
            row.FDate:=fdate;
            end;
          end;
        end;
      TThread.Synchronize(TThread.CurrentThread,
                    procedure
                    begin
                      MainForm.CatalogListData.Add(row);
                      MainForm.ProgressBar.Value:=MainForm.ProgressBar.Value+0.5;
                    end);
    end;
  until FindNext(SearchRec) <> 0;

  SL.Free;

  TThread.Synchronize(TThread.CurrentThread,
                procedure
                begin
                  MainForm.CatalogList.RowCount:=MainForm.CatalogListData.Count;
                  MainForm.ProgressBar.Visible:=false;
                end);
end;

procedure TMainForm.CatalogListGetValue(Sender: TObject; const Col,
  Row: Integer; var Value: TValue);
begin
case col  of
  0:value:=IntToStr(Row+1);
  1:value:=CatalogListData[Row].Name;
  2:value:=CatalogListData[Row].Date;
  3:if CatalogListData[Row].Previews then value:=preview_bmp;
  4:value:=CatalogListData[Row].size;
  5:value:=CatalogListData[Row].Size;
end;
end;

function SortByName(const L, R: TRowData): integer;
begin
  Result := CompareText( LowerCase(L.Name), LowerCase(R.Name) );
end;

function SortByDate(const L, R: TRowData): integer;
begin
  Result := L.FDate - R.FDate;
end;

function SortBySize(const L, R: TRowData): integer;
begin
  Result := R.Size - L.Size;
end;

procedure TMainForm.CatalogListHeaderClick(Column: TColumn);
var
  i,j:word;
begin
if not assigned(Column) then Exit;
CatalogList.BeginUpdate;
if Column.Index = LastSortColumn then begin
    CatalogListData.Reverse;
  end else begin
    if Column.Index = 1 then CatalogListData.Sort(TComparer<TRowData>.Construct(SortByName));
    if Column.Index = 2 then CatalogListData.Sort(TComparer<TRowData>.Construct(SortByDate));
    if Column.Index = 3 then
      for i:=0 to CatalogListData.Count-2 do
        if not CatalogListData[i].Previews then
          for j:=i+1 to CatalogListData.Count-1 do if CatalogListData[j].Previews then begin
            CatalogListData.Exchange(i,j);
            break;
          end;
    if Column.Index = 4 then CatalogListData.Sort(TComparer<TRowData>.Construct(SortBySize));
    LastSortColumn:=Column.Index;
  end;
CatalogList.EndUpdate;
CatalogList.Repaint;
end;

procedure TMainForm.CatalogListSelectCell(Sender: TObject; const ACol,
  ARow: Integer; var CanSelect: Boolean);
var i:integer;
begin
end;


{ TGetFolderSizeThread }


constructor TGetFolderSizeThread.Create(index: integer; Dir:string);
begin
  inherited Create(false);
  FreeOnTerminate:=true;
  findex:=index;
  fdir:=dir;
end;

procedure TGetFolderSizeThread.Done;
var
  row:TRowData;
  i:word;
  p:TProgressCell;
begin
  for i:=0 to MainForm.CatalogListData.Count do
    if MainForm.CatalogListData[i].id=findex then begin
      row:=MainForm.CatalogListData[i];
      fsize:=fsize div 1048576; //Translate in MB's, 1048576 = 1204x1024
      //row.Date:=IntToStr(fsize);
      row.Size:=fsize;
      MainForm.CatalogListData[i]:=row;
      break;
      end;
  if fsize > MainForm.SizeColumn.MaxValue then begin
    MainForm.SizeColumn.MaxValue:=fsize;
    if MainForm.LastSortColumn = 4 then begin
      MainForm.LastSortColumn := -1;
      MainForm.CatalogListHeaderClick(MainForm.SizeColumn);
      end;
    end;
  MainForm.CatalogList.UpdateColumns;
  MainForm.CatalogList.Repaint;
  //MainForm.LastSortColumn:=-1;
end;

procedure TGetFolderSizeThread.Execute;
begin
  inherited;
  fsize:=GetDirFullSize(fdir);
  synchronize(Done);
end;

{ TCustomColumn }


{ TCustomColumn }

procedure TCustomColumn.DefaultDrawCell(const Canvas: TCanvas;
  const Bounds: TRectF; const Row: Integer; const Value: TValue;
  const State: TGridDrawStates);
var
  R: TRectF;
  s:string;
begin
  R := Bounds;
  R.Inflate(2, -5);
  R.Width:=Value.AsInt64/MaxValue*R.Width;
  Canvas.Fill.Color:=$FFAAAADD;
  Canvas.FillRect(R,0,0,[],0.5);
  if Value.AsInt64>0 then
    s:=Value.ToString+' Mb' else s:='';
  inherited DefaultDrawCell(Canvas,Bounds,Row,TValue(s),State)
  //Value.
  //Value:=TValue('sda');
  //Value.ToString
end;

end.
