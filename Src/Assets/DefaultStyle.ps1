if (!("Windows.Media.Fonts" -as [Type])) {
    Add-Type -AssemblyName "PresentationCore"
}
$Font = [Windows.Media.Fonts]::SystemFontFamilies | Where-Object {$_.Source -like 'sMetropolis*' }
if ($Font) {

    DocumentOption -EnableSectionNumbering -PageSize A4 -DefaultFont 'Metropolis' -MarginLeftAndRight 71 -MarginTopAndBottom 71

    Style -Name 'Title' -Size 20 -Color '002538' -Align Center
    Style -Name 'Title 2' -Size 17 -Color '007CBB' -Align Center
    Style -Name 'Title 3' -Size 12 -Color '007CBB' -Align Left
    Style -Name 'Heading 1' -Size 20 -Color '007CBB' -Font 'Metropolis Medium'
    Style -Name 'Heading 2' -Size 17 -Color '007CBB' -Font 'Metropolis Medium' 
    Style -Name 'Heading 3' -Size 12 -Color '007CBB' -Font 'Metropolis Medium'
    Style -Name 'Heading 4' -Size 11 -Color '007CBB' -Font 'Metropolis Medium'
    Style -Name 'Heading 5' -Size 11 -Color '565656' -Font 'Metropolis Medium'
    Style -Name 'H1 Exclude TOC' -Size 20 -Color '007CBB' 
    Style -Name 'Normal' -Size 9 -Color '565656' -Default
    Style -Name 'TOC' -Size 20 -Color '007CBB' 
    Style -Name 'TableDefaultHeading' -Size 9 -Color 'FAF7EE' -BackgroundColor '002538' -Font 'Metropolis Semi Bold'
    Style -Name 'TableDefaultRow' -Size 9
    Style -Name 'TableDefaultAltRow' -Size 9 -BackgroundColor 'F4F7FC' 
    Style -Name 'Critical' -Size 9 -BackgroundColor 'FFB38F'
    Style -Name 'Warning' -Size 9 -BackgroundColor 'FFE860'
    Style -Name 'Info' -Size 9 -BackgroundColor 'A6D8E7'
    Style -Name 'OK' -Size 9 -BackgroundColor 'AADB1E'

    TableStyle -Id 'TableDefault' -HeaderStyle 'TableDefaultHeading' -RowStyle 'TableDefaultRow' -AlternateRowStyle 'TableDefaultAltRow' -BorderColor '002438' -Align Left -BorderWidth 0.5 -Default
    TableStyle -Id 'Borderless' -BorderWidth 0

    # VMware Cover Page
    BlankLine -Count 11
    Paragraph -Style Title $Global:AsBuiltConfig.Report.Name
    if ($Global:AsBuiltConfig.Company.FullName) {
        Paragraph -Style Title2 $Global:AsBuiltConfig.Company.FullName
        BlankLine -Count 49
        Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
                'Author:' = $Global:AsBuiltConfig.Report.Author
                'Date:' = Get-Date -Format 'dd MMMM yyyy'
                'Version:' = $Global:AsBuiltConfig.Report.Version
            })
        PageBreak
    } else {
        BlankLine -Count 50
        Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
                'Author:' = "Test"
                'Date:' = Get-Date -Format 'dd MMMM yyyy'
                'Version:' = "Test"
            })
        PageBreak
    }
} else {
    $DefaultFont = 'Arial'

    DocumentOption -EnableSectionNumbering -PageSize A4 -DefaultFont $DefaultFont -MarginLeftAndRight 71 -MarginTopAndBottom 71

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
    Paragraph -Style Title $Global:AsBuiltConfig.Report.Name
    if ($Global:AsBuiltConfig.Company.FullName) {
        Paragraph -Style Title2 $Global:AsBuiltConfig.Company.FullName
        BlankLine -Count 27
        Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
                'Author:' = $Global:AsBuiltConfig.Report.Author
                'Date:' = Get-Date -Format 'dd MMMM yyyy'
                'Version:' = $Global:AsBuiltConfig.Report.Version
            })
        PageBreak
    } else {
        BlankLine -Count 28
        Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
                'Author:' = $Global:AsBuiltConfig.Report.Author
                'Date:' = Get-Date -Format 'dd MMMM yyyy'
                'Version:' = $Global:AsBuiltConfig.Report.Version
            })
        PageBreak
    }
}

# Table of Contents
TOC -Name 'Table of Contents'
PageBreak
