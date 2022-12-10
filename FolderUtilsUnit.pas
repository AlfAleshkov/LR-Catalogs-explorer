unit FolderUtilsUnit;

interface

uses System.SysUtils, System.Types, System.Classes;

function GetDirFullSize(aPath: String): Int64;

implementation

function GetDirFullSize(aPath: String): Int64;
var
  sr: TSearchRec;
  tPath: String;
  sum: Int64;
begin
  sum := 0;
  tPath := IncludeTrailingBackSlash(aPath);
  if FindFirst(tPath + '*.*', faAnyFile, sr) = 0 then
  begin
    try
      repeat
        if (sr.Name = '.') or (sr.Name = '..') then
          Continue;
        if (sr.Attr and faDirectory) <> 0 then
        begin
          sum := sum + GetDirFullSize(tPath + sr.Name);
          Continue;
        end;
        sum := sum + (sr.FindData.nFileSizeHigh shl 32) + sr.FindData.nFileSizeLow;
      until FindNext(sr) <> 0;
    finally
      Result := sum;
      FindClose(sr);
    end;
  end;
end;


end.
