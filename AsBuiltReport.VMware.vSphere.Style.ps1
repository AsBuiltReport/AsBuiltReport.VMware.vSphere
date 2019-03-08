#region VMware Document Style
DocumentOption -EnableSectionNumbering -PageSize A4 -DefaultFont Arial -MarginLeftAndRight 71 -MarginTopAndBottom 71 -Orientation $Orientation

Style -Name 'Title' -Size 24 -Color '002538' -Align Center
Style -Name 'Title 2' -Size 18 -Color '007CBB' -Align Center
Style -Name 'Title 3' -Size 12 -Color '007CBB' -Align Left
Style -Name 'Heading 1' -Size 16 -Color '007CBB' 
Style -Name 'Heading 2' -Size 14 -Color '007CBB' 
Style -Name 'Heading 3' -Size 12 -Color '007CBB' 
Style -Name 'Heading 4' -Size 11 -Color '007CBB' 
Style -Name 'Heading 5' -Size 10 -Color '007CBB'
Style -Name 'H1 Exclude TOC' -Size 16 -Color '007CBB' 
Style -Name 'Normal' -Size 10 -Color '565656' -Default
Style -Name 'TOC' -Size 16 -Color '007CBB' 
Style -Name 'TableDefaultHeading' -Size 10 -Color 'FAF7EE' -BackgroundColor '002538' 
Style -Name 'TableDefaultRow' -Size 10 
Style -Name 'TableDefaultAltRow' -Size 10 -BackgroundColor 'D9E4EA' 
Style -Name 'Critical' -Size 10 -BackgroundColor 'FFB38F'
Style -Name 'Warning' -Size 10 -BackgroundColor 'FFE860'
Style -Name 'Info' -Size 10 -BackgroundColor 'A6D8E7'
Style -Name 'OK' -Size 10 -BackgroundColor 'AADB1E'

TableStyle -Id 'TableDefault' -HeaderStyle 'TableDefaultHeading' -RowStyle 'TableDefaultRow' -AlternateRowStyle 'TableDefaultAltRow' -BorderColor '002538' -Align Left -BorderWidth 0.5 -Default
TableStyle -Id 'Borderless' -BorderWidth 0

# VMware Cover Page
BlankLine -Count 11
Paragraph -Style Title $ReportName
if ($Company.FullName) {
    Paragraph -Style Title2 $Company.FullName
    BlankLine -Count 27
    Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
            'Author:' = $Author
            'Date:' = Get-Date -Format 'dd MMMM yyyy'
            'Version:' = $Version
        })
    PageBreak
} else {
    BlankLine -Count 28
    Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
            'Author:' = $Author
            'Date:' = Get-Date -Format 'dd MMMM yyyy'
            'Version:' = $Version
        })
    PageBreak
}

# Table of Contents
TOC -Name 'Table of Contents'
PageBreak
#endregion VMware Document Style