param (
    [object]$InputData   # Can be a CSV file path (string) OR in-memory data (Hashtable/Array)
)

# Load WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to check if input is a valid file
function Test-ValidFile {
    param ([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        [System.Windows.MessageBox]::Show("Error: CSV file not found at $FilePath") | Out-Null
        exit
    }

    if ((Import-Csv -Path $FilePath | Measure-Object).Count -eq 0) {
        [System.Windows.MessageBox]::Show("Error: CSV file is empty or invalid.") | Out-Null
        exit
    }
}

# Function to check if input is valid in-memory data
function Test-ValidData {
    param ([object]$Data)

    if (($Data | Measure-Object).Count -eq 0) {
        [System.Windows.MessageBox]::Show("Error: Provided data is empty or invalid.") | Out-Null
        exit
    }
}

# Determine if InputData is a file path or an in-memory object
if ($InputData -is [string] -and (Test-Path $InputData)) {
    Test-ValidFile -FilePath $InputData
}
elseif ($InputData -is [System.Collections.IEnumerable]) {
    Test-ValidData -Data $InputData
}
else {
    [System.Windows.MessageBox]::Show("Error: Invalid input. Provide a valid CSV file path or in-memory data.") | Out-Null
    exit
}

# Create Window
$window = New-Object System.Windows.Window
$window.Title = "Unified Audit Log Viewer"
$window.Width = 1400
$window.Height = 800
$window.WindowStartupLocation = "CenterScreen"
$window.FontFamily = "Segoe UI"
$window.FontSize = 12
# $treeView.FontSize = "14"
$window.FontWeight = "Normal"

# Create Grid
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = "10"  # Add margin around the grid
$window.Content = $grid  # Set the grid as the window's content

# Define columns for the main Grid (percentage-based)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "3*" }))  # Column 0: TreeView (25%)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "5*" }))  # Column 1: Preview Pane (50%)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "3*" }))  # Column 2: Detailed Info Pane (25%)

# Define rows for the main Grid
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))  # Row 0: Header
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))      # Row 1: Main Content (stretches to fill remaining space)
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))  # Row 2: Footer




############t Tree View  Configuration ######################

# Create the Grid for the TreeView section
$treeViewGrid = New-Object System.Windows.Controls.Grid
$treeViewGrid.Margin = "5"
$treeViewGrid.VerticalAlignment = "Stretch"
$treeViewGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$treeViewGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$treeViewGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TreeView (fills remaining space)

# Add the TreeView Grid to the main Grid
$grid.Children.Add($treeViewGrid)
[System.Windows.Controls.Grid]::SetRow($treeViewGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($treeViewGrid, 0)

# Create the Label
$treeViewLabel = New-Object System.Windows.Controls.Label
$treeViewLabel.Content = "Audit Data:"
$treeViewLabel.FontSize = 18
$treeViewLabel.FontWeight = "Bold"

# Add the Label to Row 0 of the TreeView Grid
$treeViewGrid.Children.Add($treeViewLabel)
[System.Windows.Controls.Grid]::SetRow($treeViewLabel, 0)


# Create the TreeView
$treeView = New-Object System.Windows.Controls.TreeView
$treeView.ToolTip = "Browse the audit log data hierarchically."
$treeView.VerticalAlignment = "Stretch"  # Ensure TreeView stretches vertically
$treeView.HorizontalAlignment = "Stretch"
$treeView.Background = "LightYellow"
$treeView.Padding = "10"
$treeView.Margin = "5"
$treeView.FontFamily = "Segoe UI"
$treeView.FontSize = "12"
$treeView.BorderBrush = "DarkGreen"
$treeView.BorderThickness = "1"


# Enable virtualization for TreeView
$treeView.ItemsPanel = New-Object System.Windows.Controls.ItemsPanelTemplate -ArgumentList @(
    [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.VirtualizingStackPanel])
$treeView.SetValue([System.Windows.Controls.VirtualizingStackPanel]::IsVirtualizingProperty, $true)
$treeView.SetValue([System.Windows.Controls.VirtualizingStackPanel]::VirtualizationModeProperty, [System.Windows.Controls.VirtualizationMode]::Recycling))


# Add the TreeView to Row 1 of the TreeView Grid
$treeViewGrid.Children.Add($treeView)
[System.Windows.Controls.Grid]::SetRow($treeView, 1)

# Event Handler for TreeView Selection Changed
$treeView.Add_SelectedItemChanged({
    $selectedItems = $treeView.SelectedItems

    # Update the Preview Pane with the selected log entries
    Update-PreviewPane -SelectedItems $selectedItems
})





############ Preview Pane Configuration ##################

# Create the Preview Pane Grid
$previewPaneGrid = New-Object System.Windows.Controls.Grid
$previewPaneGrid.Margin = "5"
$previewPaneGrid.VerticalAlignment = "Stretch"
$previewPaneGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$previewPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$previewPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TextBox (fills remaining space)

# Add the Preview Pane Grid to the main Grid
$grid.Children.Add($previewPaneGrid)
[System.Windows.Controls.Grid]::SetRow($previewPaneGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($previewPaneGrid, 1)

# Create the Label
$previewPaneLabel = New-Object System.Windows.Controls.Label
$previewPaneLabel.Content = "Audit Preview:"
$previewPaneLabel.FontSize = 18
$previewPaneLabel.FontWeight = "Bold"

# Add the Label to Row 0 of the Preview Pane Grid
$previewPaneGrid.Children.Add($previewPaneLabel)
[System.Windows.Controls.Grid]::SetRow($previewPaneLabel, 0)

# Create the Preview Pane (TextBox)
$previewPane = New-Object System.Windows.Controls.TextBox
$previewPane.IsReadOnly = $true
$previewPane.VerticalScrollBarVisibility = "Auto"
$previewPane.HorizontalScrollBarVisibility = "Auto"
$previewPane.ToolTip = "Preview of the selected log entry."
$previewPane.VerticalAlignment = "Stretch"  # Ensure it stretches vertically
$previewPane.HorizontalAlignment = "Stretch"  # Ensure it stretches horizontally

# Add the Preview Pane (TextBox) to Row 1 of the Preview Pane Grid
$previewPaneGrid.Children.Add($previewPane)
[System.Windows.Controls.Grid]::SetRow($previewPane, 1)



############ Detailed Info Pane Configuration ##################

# Create the Detailed Info Pane Grid
$detailedInfoPaneGrid = New-Object System.Windows.Controls.Grid
$detailedInfoPaneGrid.Margin = "5"
$detailedInfoPaneGrid.VerticalAlignment = "Stretch"
$detailedInfoPaneGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$detailedInfoPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$detailedInfoPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TextBox (fills remaining space)

# Add the Detailed Info Pane Grid to the main Grid
$grid.Children.Add($detailedInfoPaneGrid)
[System.Windows.Controls.Grid]::SetRow($detailedInfoPaneGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($detailedInfoPaneGrid, 2)

# Create the Label
$detailedInfoPaneLabel = New-Object System.Windows.Controls.Label
$detailedInfoPaneLabel.Content = "Audit Detail:"
$detailedInfoPaneLabel.FontSize = 18
$detailedInfoPaneLabel.FontWeight = "Bold"

# Add the Label to Row 0 of the Detailed Info Pane Grid
$detailedInfoPaneGrid.Children.Add($detailedInfoPaneLabel)
[System.Windows.Controls.Grid]::SetRow($detailedInfoPaneLabel, 0)

# Create the Detailed Info Pane (TextBox)
$detailedInfoTextBox = New-Object System.Windows.Controls.TextBox
$detailedInfoTextBox.IsReadOnly = $true
$detailedInfoTextBox.VerticalAlignment = "Stretch"  # Ensure it stretches vertically
$detailedInfoTextBox.HorizontalAlignment = "Stretch"  # Ensure it stretches horizontally
$detailedInfoTextBox.VerticalScrollBarVisibility = "Auto"
$detailedInfoTextBox.HorizontalScrollBarVisibility = "Auto"
# $detailedInfoTextBox.Margin = "5"  # Add margin for better spacing
$detailedInfoTextBox.ToolTip = "View detailed information about the selected item."

# Add the TextBox to Row 1 of the Detailed Info Pane Grid
$detailedInfoPaneGrid.Children.Add($detailedInfoTextBox)
[System.Windows.Controls.Grid]::SetRow($detailedInfoTextBox, 1)




################### Filter by Search ###################

# Add a Grid to hold the search components
$searchPanel = New-Object System.Windows.Controls.Grid
$searchPanel.Margin = "10"
$searchPanel.VerticalAlignment = "Center"
$searchPanel.HorizontalAlignment = "Stretch"  # Stretch to fill available space

# Define columns for the search panel
$searchPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))  # Column 0: Search Box (fills remaining space)
$searchPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))  # Column 1: Filter Button (fits content)

# Add Search Box
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = [double]::NaN  # Auto-size width to fill available space
$searchBox.Height = 30
$searchBox.Margin = "5"
$searchBox.VerticalAlignment = "Center"
$searchBox.HorizontalAlignment = "Stretch"  # Stretch to fill available space
$searchBox.TextAlignment = "Left"
$searchBox.FontSize = "14"
$searchBox.ToolTip = "Enter a keyword to filter log entries."
$searchBox.Background = "White"
$searchBox.BorderBrush = "Gray"
$searchBox.BorderThickness = "1"
$searchBox.Padding = "5"

# Add Filter Button
$filterButton = New-Object System.Windows.Controls.Button
$filterButton.Content = "Keyword"
$filterButton.Height = 30
$filterButton.Margin = "5"
$filterButton.VerticalAlignment = "Center"
$filterButton.HorizontalAlignment = "Left"
$filterButton.FontSize = "14"
$filterButton.Padding = "10,5,10,5"  # Inner padding (left, top, right, bottom)
$filterButton.BorderThickness = "1"
$filterButton.ToolTip = "Filter log entries based on the search term/keyword."
$filterButton.Add_Click({
    Update-TreeView  # Call the filter function
})


# Add the search components to the grid
$searchPanel.Children.Add($searchBox)
[System.Windows.Controls.Grid]::SetColumn($searchBox, 0)

$searchPanel.Children.Add($filterButton)
[System.Windows.Controls.Grid]::SetColumn($filterButton, 1)

# # Add the search panel to the grid or parent container
$grid.Children.Add($searchPanel)
[System.Windows.Controls.Grid]::SetRow($searchPanel, 0)  # Place in Row 0 (Header)
[System.Windows.Controls.Grid]::SetColumn($searchPanel, 0)  # Place in Column 0
# [System.Windows.Controls.Grid]::SetColumnSpan($searchPanel, 3)  # Span all 3 columns


#################### Filter by RecordType, Operation, Date and Time #####################

# Add Advanced Filter Panel
$filterPanel = New-Object System.Windows.Controls.WrapPanel  # Use StackPanel for vertical layout
$filterPanel.Orientation = "Horizontal"
$filterPanel.HorizontalAlignment = "Stretch"
$filterPanel.VerticalAlignment = "Center"
$filterPanel.Margin = "10"
$grid.Children.Add($filterPanel)
[System.Windows.Controls.Grid]::SetRow($filterPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($filterPanel, 1)

# Add Parent Label "Filters"
$filtersLabel = New-Object System.Windows.Controls.Label
$filtersLabel.Content = "Filters:"
$filtersLabel.Margin = "5"
$filtersLabel.VerticalAlignment = "Center"
$filtersLabel.FontSize = "16"
$filtersLabel.FontWeight = "Bold"
$filterPanel.Children.Add($filtersLabel)

# Group RecordType Label and Dropdown
$recordTypeGroup = New-Object System.Windows.Controls.StackPanel
$recordTypeGroup.Orientation = "Horizontal"
$recordTypeGroup.Margin = "5"
$recordTypeGroup.VerticalAlignment = "Center"

# Add Label for RecordType Filter
$recordTypeLabel = New-Object System.Windows.Controls.Label
$recordTypeLabel.Content = "RecordType:"
$recordTypeLabel.Margin = "5"
$recordTypeLabel.VerticalAlignment = "Center"
$recordTypeLabel.FontSize = "14"

# Add RecordType Filter Dropdown
$recordTypeFilter = New-Object System.Windows.Controls.ComboBox
$recordTypeFilter.Width = 150
$recordTypeFilter.Height = 25
$recordTypeFilter.Margin = "5"
$recordTypeFilter.ToolTip = "Filter by RecordType"
$recordTypeFilter.FontSize = "14"
$recordTypeFilter.Add_SelectionChanged({
    Update-TreeView
})

# Add Label and Dropdown to the RecordType Group
$recordTypeGroup.Children.Add($recordTypeLabel)
$recordTypeGroup.Children.Add($recordTypeFilter)

# Group Operations Label and Dropdown
$operationsGroup = New-Object System.Windows.Controls.StackPanel
$operationsGroup.Orientation = "Horizontal"
$operationsGroup.Margin = "5"
$operationsGroup.VerticalAlignment = "Center"

# Add Label for Operations Filter
$operationsLabel = New-Object System.Windows.Controls.Label
$operationsLabel.Content = "Operation:"
$operationsLabel.Margin = "5"
$operationsLabel.VerticalAlignment = "Center"
$operationsLabel.FontSize = "14"

# Add Operations Filter Dropdown
$operationsFilter = New-Object System.Windows.Controls.ComboBox
$operationsFilter.Width = 150
$operationsFilter.Height = 25
$operationsFilter.Margin = "5"
$operationsFilter.ToolTip = "Filter by Operations"
$operationsFilter.FontSize = "14"
$operationsFilter.Add_SelectionChanged({
    Update-TreeView
})

# Add Label and Dropdown to the Operations Group
$operationsGroup.Children.Add($operationsLabel)
$operationsGroup.Children.Add($operationsFilter)

# Group Date Range Label, Start Date, and End Date
$dateRangeGroup = New-Object System.Windows.Controls.StackPanel
$dateRangeGroup.Orientation = "Horizontal"
$dateRangeGroup.Margin = "5"
$dateRangeGroup.VerticalAlignment = "Center"

# Add Label for Date Range Filter
$dateRangeLabel = New-Object System.Windows.Controls.Label
$dateRangeLabel.Content = "Date Range:"
$dateRangeLabel.Margin = "5"
$dateRangeLabel.VerticalAlignment = "Center"
$dateRangeLabel.FontSize = "14"

# Add Start Date Picker
$startDatePicker = New-Object System.Windows.Controls.DatePicker
$startDatePicker.Width = 110
$startDatePicker.Margin = "5"
$startDatePicker.ToolTip = "Select start date"
$startDatePicker.FontSize = "14"
$startDatePicker.Add_SelectedDateChanged({
    Update-TreeView
})

# Add End Date Picker
$endDatePicker = New-Object System.Windows.Controls.DatePicker
$endDatePicker.Width = 110
$endDatePicker.Margin = "5"
$endDatePicker.ToolTip = "Select end date"
$endDatePicker.FontSize = "14"
$endDatePicker.Add_SelectedDateChanged({
    Update-TreeView
})

# Add Date Range components to the Date Range Group
$dateRangeGroup.Children.Add($dateRangeLabel)
$dateRangeGroup.Children.Add($startDatePicker)
$dateRangeGroup.Children.Add($endDatePicker)

# Group Time Label, Start Time, and End Time
$timeGroup = New-Object System.Windows.Controls.StackPanel
$timeGroup.Orientation = "Horizontal"
$timeGroup.Margin = "5"
$timeGroup.VerticalAlignment = "Center"

# Add Label for Time Filter
$timeLabel = New-Object System.Windows.Controls.Label
$timeLabel.Content = "Time:"
$timeLabel.Margin = "5"
$timeLabel.VerticalAlignment = "Center"
$timeLabel.FontSize = "14"

# Add Start Time ComboBox
$startTimeComboBox = New-Object System.Windows.Controls.ComboBox
$startTimeComboBox.Width = 80
$startTimeComboBox.Margin = "5"
$startTimeComboBox.ToolTip = "Select start time"
$startTimeComboBox.IsEditable = $true  # Allow manual input
$startTimeComboBox.Text = "00:00:00"   # Default start time
$startTimeComboBox.FontSize = "14"
# $startTimeComboBox.Add_TextChanged({
#     Update-TreeView
# })
# Add TextChanged event handler for Start Time ComboBox
$startTimeComboBox.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent, [System.Windows.RoutedEventHandler]{
    Update-TreeView
})

# Add End Time ComboBox
$endTimeComboBox = New-Object System.Windows.Controls.ComboBox
$endTimeComboBox.Width = 80
$endTimeComboBox.Margin = "5"
$endTimeComboBox.ToolTip = "Select end time"
$endTimeComboBox.IsEditable = $true    # Allow manual input
$endTimeComboBox.Text = "23:59:59"     # Default end time
$endTimeComboBox.FontSize = "14"
# $endTimeComboBox.Add_TextChanged({
#     Update-TreeView
# })
# Add TextChanged event handler for End Time ComboBox
$endTimeComboBox.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent, [System.Windows.RoutedEventHandler]{
    Update-TreeView
})

# Populate ComboBoxes with time values
$timeValues = @()
for ($hour = 0; $hour -lt 24; $hour++) {
    for ($minute = 0; $minute -lt 60; $minute++) {
        $timeValues += "{0:D2}:{1:D2}:00" -f $hour, $minute
    }
}

# Add time values to ComboBoxes
$timeValues | ForEach-Object {
    $startTimeComboBox.Items.Add($_) | Out-Null
    $endTimeComboBox.Items.Add($_) | Out-Null
}

# Add Time components to the Time Group
$timeGroup.Children.Add($timeLabel)
$timeGroup.Children.Add($startTimeComboBox)
$timeGroup.Children.Add($endTimeComboBox)

# Add groups to the filter panel
$filterPanel.Children.Add($recordTypeGroup)
$filterPanel.Children.Add($operationsGroup)
$filterPanel.Children.Add($dateRangeGroup)
$filterPanel.Children.Add($timeGroup)



################ Other feature ####################

# Add a StackPanel to Row 1, Column 1 for buttons
$buttonPanel = New-Object System.Windows.Controls.WrapPanel
$buttonPanel.Orientation = "Horizontal"
$buttonPanel.HorizontalAlignment = "Stretch"
$buttonPanel.VerticalAlignment = "Center"
$buttonPanel.Margin = "10"
$grid.Children.Add($buttonPanel)
[System.Windows.Controls.Grid]::SetRow($buttonPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($buttonPanel, 2)


# Add Export to JSON Button
$exportJsonButton = New-Object System.Windows.Controls.Button
$exportJsonButton.Content = "Export to JSON"
$exportJsonButton.Width = 100
$exportJsonButton.Height = 25
$exportJsonButton.Margin = "5"
$exportJsonButton.ToolTip = "Export the displayed data to a JSON file."
$exportJsonButton.Add_Click({
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "JSON Files (*.json)|*.json"
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $logDataArray | ConvertTo-Json -Depth 10 | Out-File -FilePath $saveFileDialog.FileName
            [System.Windows.MessageBox]::Show("Data exported to JSON successfully!") | Out-Null
        }
    })

# Add Export to CSV Button
$exportCsvButton = New-Object System.Windows.Controls.Button
$exportCsvButton.Content = "Export to CSV"
$exportCsvButton.Width = 100
$exportCsvButton.Height = 25
$exportCsvButton.Margin = "5"
$exportCsvButton.ToolTip = "Export the displayed data to a CSV file."
$exportCsvButton.Add_Click({
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $logDataArray | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
            [System.Windows.MessageBox]::Show("Data exported to CSV successfully!") | Out-Null
        }
    })

# Add Refresh Button
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Content = "Refresh"
$refreshButton.Width = 75
$refreshButton.Height = 25
$refreshButton.Margin = "5"
$refreshButton.ToolTip = "Refresh reloads the data sets"
$refreshButton.Add_Click({
        # Clear the TreeView
        $treeView.Items.Clear()

        # Reload the data
        $logDataArray = Load-AuditLogData -DataInput $InputData

        # Repopulate filters
        Populate-Filters

        # Reset date pickers
        $startDatePicker.SelectedDate = $null
        $endDatePicker.SelectedDate = $null

        # Reapply filters (including date range)
        Update-TreeView

        # Update status bar
        $statusBar.Text = "Data refreshed successfully!"
    })

# Add Theme Toggle Button
$themeButton = New-Object System.Windows.Controls.Button
$themeButton.Content = "Toggle Theme"
$themeButton.Width = 100
$themeButton.Height = 25
$themeButton.ToolTip = "Change UI to dark mode"
$themeButton.Margin = "5"
$themeButton.Add_Click({
        if ($window.Background -eq [System.Windows.Media.Brushes]::White) {
            $window.Background = [System.Windows.Media.Brushes]::Black
            $window.Foreground = [System.Windows.Media.Brushes]::White
        }
        else {
            $window.Background = [System.Windows.Media.Brushes]::White
            $window.Foreground = [System.Windows.Media.Brushes]::Black
        }
    })


# Add Expand/Collapse Buttons
$expandButton = New-Object System.Windows.Controls.Button
$expandButton.Content = "Expand All"
$expandButton.Width = 75
$expandButton.Height = 25
$expandButton.Margin = "5"
$expandButton.ToolTip = "Expand all collapsed logs"
$expandButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $true
        }
    })

$collapseButton = New-Object System.Windows.Controls.Button
$collapseButton.Content = "Collapse All"
$collapseButton.Width = 75
$collapseButton.Height = 25
$collapseButton.Margin = "5"
$collapseButton.ToolTip = "Collapse all expanded logs"
$collapseButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $false
        }
})

$clearFiltersButton = New-Object System.Windows.Controls.Button
$clearFiltersButton.Content = "Clear Filters"
$clearFiltersButton.Width = 75
$clearFiltersButton.Height = 25
    $clearFiltersButton.Add_Click({
        $searchBox.Text = ""
        $recordTypeFilter.SelectedIndex = 0
        $operationsFilter.SelectedIndex = 0
        $startDatePicker.SelectedDate = $null
        $endDatePicker.SelectedDate = $null
        $startTimeComboBox.Text = "00:00:00"
        $endTimeComboBox.Text = "23:59:59"
        Update-TreeView
})

# update

$buttonPanel.Children.Add($exportJsonButton)
$buttonPanel.Children.Add($exportCsvButton)
$buttonPanel.Children.Add($refreshButton)
$buttonPanel.Children.Add($expandButton)
$buttonPanel.Children.Add($collapseButton)
$buttonPanel.Children.Add($themeButton)
$buttonPanel.Children.Add($clearFiltersButton)


###################################################

# Add Progress Bar
$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Width = 300
$progressBar.Height = 20
$progressBar.HorizontalAlignment = "Center"
$progressBar.VerticalAlignment = "Bottom"
$progressBar.Margin = "10"
$grid.Children.Add($progressBar)
[System.Windows.Controls.Grid]::SetRow($progressBar, 2)
[System.Windows.Controls.Grid]::SetColumn($progressBar, 0)

# Add Status Bar
$statusBar = New-Object System.Windows.Controls.TextBlock
$statusBar.Width = 300
$statusBar.Height = 20
$statusBar.Margin = "10"
$statusBar.VerticalAlignment = "Bottom"
$statusBar.HorizontalAlignment = "Left"
$grid.Children.Add($statusBar)
[System.Windows.Controls.Grid]::SetRow($statusBar, 2)
[System.Windows.Controls.Grid]::SetColumn($statusBar, 1)



# Function to Update the Preview Pane
function Format-PropertyValue {
    param (
        [object]$Value,
        [int]$IndentLevel = 0
    )

    $indent = "  " * $IndentLevel  # Create indentation based on the nesting level

    if ($null -eq $Value) {
        return "${indent}N/A"
    }
    elseif ($Value -is [array]) {
        $result = @()
        foreach ($item in $Value) {
            $result += Format-PropertyValue -Value $item -IndentLevel ($IndentLevel + 1)
        }
        return $result -join "`n"
    }
    elseif ($Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [System.Collections.IDictionary]) {
        $result = @()
        foreach ($key in $Value.PSObject.Properties.Name) {
            $subValue = Format-PropertyValue -Value $Value.$key -IndentLevel ($IndentLevel + 1)
            
            # If the value is an array or nested object, format it with proper indentation
            if ($Value.$key -is [array] -or $Value.$key -is [System.Management.Automation.PSCustomObject]) {
                $result += "${indent}- ${key}:`n$subValue"
            }
            else {
                $result += "${indent}- ${key}: $subValue"
            }
        }
        return $result -join "`n"
    }
    elseif ($Value -is [string]) {
        # Attempt to parse JSON strings
        try {
            $parsedValue = $Value | ConvertFrom-Json -ErrorAction Stop
            return Format-PropertyValue -Value $parsedValue -IndentLevel $IndentLevel
        }
        catch {
            # If parsing fails, treat it as a regular string
            return "${indent}$($Value)"
        }
    }
    else {
        return "${indent}$($Value.ToString())"
    }
}

function Update-PreviewPane {
    param (
        [object]$SelectedItem
    )

    if ($null -eq $SelectedItem) {
        $previewPane.Text = "No log entry selected."
        return
    }

    # Extract all properties dynamically
    $previewText = @()

    $previewText += "===== Log Entry =====`n"
    
    foreach ($key in $SelectedItem.PSObject.Properties.Name) {
        $value = $SelectedItem.$key
        $formattedValue = Format-PropertyValue -Value $value
        $previewText += "$($key):   $($formattedValue)`n"
    }

    $previewText += "`n===== Log End =====`n"

    # Update the Preview Pane
    $previewPane.Text = $previewText -join ""
}

# # Event Handler for TreeView Selection Changed
$treeView.Add_SelectedItemChanged({
        $selectedItem = $treeView.SelectedItem

        if ($selectedItem -and $selectedItem.Tag) {
            # Update the Preview Pane with the selected log entry
            Update-PreviewPane -SelectedItem $selectedItem.Tag
        }
        else {
            $previewPane.Text = "No log entry selected."
        }
    })




# Function to recursively add JSON data to the TreeView
function Add-TreeNode {
    param (
        [System.Windows.Controls.TreeViewItem]$parentNode,
        [string]$key,
        $value
    )

    # Create a new TreeViewItem for the key-value pair
    $node = New-Object System.Windows.Controls.TreeViewItem

    # Display the key and value in the header
    if ($null -eq $value) {
        $node.Header = "$($key)"
    }
    else {
        $node.Header = "$($key)"
    }

    $node.Tag = $value

    # Add a tooltip to display the full value
    $node.ToolTip = if ($null -eq $value) { "Null or empty data" } else { $value.ToString() }

    if ($value -is [System.Collections.IDictionary]) {
        # If the value is a dictionary, recursively add its key-value pairs
        foreach ($subKey in $value.Keys) {
            Add-TreeNode -parentNode $node -key $subKey -value $value[$subKey]
        }
    }
    elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        # If the value is a collection (but not a string), add each item
        $index = 0
        foreach ($item in $value) {
            Add-TreeNode -parentNode $node -key "Item $index" -value $item
            $index++
        }
    }
    else {
        # For simple values, add a click event handler to display detailed information
        $node.AddHandler(
            [System.Windows.Controls.TreeViewItem]::MouseLeftButtonUpEvent,
            [System.Windows.RoutedEventHandler] {
                param ($sender, $e)
                if ($null -eq $sender.Tag) {
                    $detailedInfoTextBox.Text = "Null or empty data"
                }
                else {
                    $detailedInfoTextBox.Text = $sender.Tag | ConvertTo-Json -Depth 10
                }
            }
        )

        # Highlight search results if a search term is provided
        if (-not [string]::IsNullOrEmpty($searchBox.Text)) {
            $searchText = $searchBox.Text
            $text = if ($null -eq $value) { "" } else { $value.ToString() }

            if ($regexCheckBox.IsChecked) {
                try {
                    $matchesText = [regex]::Matches($text, $searchText)
                    $lastIndex = 0
                    $textBlock = New-Object System.Windows.Controls.TextBlock

                    foreach ($match in $matchesText) {
                        # Add text before the match
                        if ($match.Index -gt $lastIndex) {
                            $textBlock.Inlines.Add($text.Substring($lastIndex, $match.Index - $lastIndex))
                        }

                        # Add the match with highlighting
                        $run = New-Object System.Windows.Documents.Run $match.Value
                        $run.Background = [System.Windows.Media.Brushes]::Yellow
                        $run.FontWeight = "Bold"
                        $textBlock.Inlines.Add($run)

                        # Update the last index
                        $lastIndex = $match.Index + $match.Length
                    }

                    # Add the remaining text after the last match
                    if ($lastIndex -lt $text.Length) {
                        $textBlock.Inlines.Add($text.Substring($lastIndex))
                    }

                    # Set the TextBlock as the header of the TreeViewItem
                    $node.Header = $textBlock
                }
                catch {
                    # If regex is invalid, display the text without highlighting
                    $node.Header = "$($key)"
                }
            }
            else {
                # Simple text search (case-insensitive)
                $index = $text.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase)
                if ($index -ge 0) {
                    $textBlock = New-Object System.Windows.Controls.TextBlock

                    # Add text before the match
                    $textBlock.Inlines.Add($text.Substring(0, $index))

                    # Add the match with highlighting
                    $run = New-Object System.Windows.Documents.Run $searchText
                    $run.Background = [System.Windows.Media.Brushes]::Yellow
                    $run.FontWeight = "Bold"
                    $textBlock.Inlines.Add($run)

                    # Add the remaining text after the match
                    $textBlock.Inlines.Add($text.Substring($index + $searchText.Length))

                    # Set the TextBlock as the header of the TreeViewItem
                    $node.Header = $textBlock
                }
            }
        }
    }

    # Add the node to the parent node
    $parentNode.Items.Add($node)
}

# Function to Load Audit Log Data with Progress
function Load-AuditLogData {
    param ([object]$DataInput)

    $progressBar.Value = 0
    $statusBar.Text = "Loading data..."

    if ($DataInput -is [string] -and (Test-Path $DataInput)) {
        $ParsedDataInput = Import-Csv -Path $DataInput
    }
    elseif ($DataInput -is [System.Collections.IEnumerable]) {
        $ParsedDataInput = $DataInput
    }
    else {
        Write-Host "Invalid input! Provide a valid CSV file path or in-memory data."
        exit
    }

    $logDataArray = @()
    $totalCount = $ParsedDataInput.Count
    $currentCount = 0

    $ParsedDataInput | ForEach-Object {
        $currentCount++
        $progressBar.Value = ($currentCount / $totalCount) * 100
        $statusBar.Text = "Loading item $currentCount of $totalCount..."

        $LogEntry = $_

        $_.PSObject.Properties | ForEach-Object {


            if ($_.Name -eq "AuditData") {
                Write-Host $_
                try {
                    $_.Value = ConvertFrom-Json $LogEntry.AuditData -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to parse AuditData JSON for entry"
                    $_.Value = $null
                }
            }
        }
        $logDataArray += $_
    }

    $progressBar.Value = 100
    $statusBar.Text = "Data loaded successfully!"

    return $logDataArray
}

# Function to populate dropdowns with unique values
function Populate-Filters {
    # Clear existing items
    $recordTypeFilter.Items.Clear()
    $operationsFilter.Items.Clear()

    # Add "All" option to both dropdowns
    $recordTypeFilter.Items.Add("All")
    $operationsFilter.Items.Add("All")

    # Get unique RecordType and Operations values
    $uniqueRecordTypes = $logDataArray | ForEach-Object { $_.RecordType } | Sort-Object -Unique
    $uniqueOperations = $logDataArray | ForEach-Object { $_.Operations } | Sort-Object -Unique

    # Add unique values to dropdowns
    foreach ($recordType in $uniqueRecordTypes) {
        $recordTypeFilter.Items.Add($recordType)
    }
    foreach ($operation in $uniqueOperations) {
        $operationsFilter.Items.Add($operation)
    }

    # Set default selection to "All"
    $recordTypeFilter.SelectedIndex = 0
    $operationsFilter.SelectedIndex = 0
}

# Function to Filter TreeView



function Update-TreeView {
    $searchText = $searchBox.Text.ToLower()
    $selectedRecordType = $recordTypeFilter.SelectedValue
    $selectedOperation = $operationsFilter.SelectedValue

    # Combine date and time for start and end filters
    $startDate = $startDatePicker.SelectedDate
    $startTime = $startTimeComboBox.Text
    $endDate = $endDatePicker.SelectedDate
    $endTime = $endTimeComboBox.Text

    # Parse start and end DateTime
    $startDateTime = $null
    $endDateTime = $null

    if ($null -ne $startDate -and -not [string]::IsNullOrEmpty($startTime)) {
        try {
            $startDateTime = [datetime]::ParseExact("$($startDate.ToString('MM/dd/yyyy')) $startTime", "MM/dd/yyyy HH:mm:ss", $null)
            # Write-Host "The Start Date time is $($startDateTime)"
        }
        catch {
            Write-Warning "Invalid start date or time format."
        }
    }

    if ($null -ne $endDate -and -not [string]::IsNullOrEmpty($endTime)) {
        try {
            $endDateTime = [datetime]::ParseExact("$($endDate.ToString('MM/dd/yyyy')) $endTime", "MM/dd/yyyy HH:mm:ss", $null)
            # Write-Host "The End Date time is $($endDateTime)"
        }
        catch {
            Write-Warning "Invalid end date or time format."
        }
    }

    $treeView.Items.Clear()

    foreach ($logData in $logDataArray) {
        $logDate = $null
        if ([string]::IsNullOrEmpty($logData.CreationDate) -or ([Datetime]$logData.CreationDate -is [datetime])) {
            try {
                # $logDate = [datetime]$logData.CreationDate -f "MM/dd/yyyy HH:mm:ss"
                $logDate = [datetime]::ParseExact($logData.CreationDate, "M/d/yyyy h:mm:ss tt", $null)
                # Write-Host "The Log Date time is $($logDate)"
            }
            catch {
                Write-Warning "Failed to parse CreationDate for entry: $($logData.CreationDate)"
                continue  # Skip this entry if the date is invalid
            }
        }

        # Apply filters
        $matchesRecordType = ($selectedRecordType -eq "All" -or $logData.RecordType -eq $selectedRecordType)
        $matchesOperation = ($selectedOperation -eq "All" -or $logData.Operations -eq $selectedOperation)
        $matchesSearch = ($logData.AuditData -match $searchText -or $logData.ResultIndex -match $searchText)
        $matchesDateRange = ($null -eq $startDateTime -or $logDate -ge $startDateTime) -and ($null -eq $endDateTime -or $logDate -le $endDateTime)

        # Write-Host "LogDate: $($logDate) matchesDateRange result against `nStart time: $($startDateTime) `nEndtime :$($endDateTime) matchesDateRange result: $matchesDateRange"

        if ($matchesRecordType -and $matchesOperation -and $matchesSearch -and $matchesDateRange) {
            $entryNode = New-Object System.Windows.Controls.TreeViewItem
            $entryNode.Header = "$($logData.RecordType) - $($logData.Operations)"
            $entryNode.Tag = $logData  # Store the log entry data in the Tag property
            $treeView.Items.Add($entryNode)

            foreach ($key in $logData.PSObject.Properties.Name) {
                if ($key -eq "AuditData") {
                    $auditNode = New-Object System.Windows.Controls.TreeViewItem
                    $auditNode.Header = "AuditData"
                    $entryNode.Items.Add($auditNode)

                    foreach ($auditKey in $logData.AuditData.PSObject.Properties.Name) {
                        $auditValue = $logData.AuditData.$auditKey

                        if ($auditKey -eq "Parameters" -and $auditValue -is [System.Collections.IEnumerable]) {
                            $paramNode = New-Object System.Windows.Controls.TreeViewItem
                            $paramNode.Header = "Parameters"
                            $auditNode.Items.Add($paramNode)

                            foreach ($param in $auditValue) {
                                try {
                                    $paramValue = ConvertFrom-Json $param.Value -ErrorAction Stop
                                }
                                catch {
                                    $paramValue = $param.Value
                                }
                                Add-TreeNode -parentNode $paramNode -key $param.Name -value $paramValue
                            }
                        }
                        else {
                            Add-TreeNode -parentNode $auditNode -key $auditKey -value $auditValue
                        }
                    }
                }
                else {
                    Add-TreeNode -parentNode $entryNode -key $key -value $logData.$key
                }
            }
        }
    }
}


# Load data from either CSV file or in-memory object
$logDataArray = Load-AuditLogData -DataInput $InputData

# Populate dropdowns with unique values
Populate-Filters

# Populate TreeView
Update-TreeView

# Show Window
$window.ShowDialog()