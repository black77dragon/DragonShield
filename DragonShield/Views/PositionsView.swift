// DragonShield/Views/PositionsView.swift
// MARK: - Version 1.2 (2025-06-16)
// MARK: - History
// - 1.1 -> 1.2: Updated to use global PositionReportData type.
// - 1.0 -> 1.1: Display live PositionReports data from database.
// - Initial creation: Displays positions with upload and report dates.

import SwiftUI

struct PositionsView: View {
  @EnvironmentObject var dbManager: DatabaseManager

  @State private var positions: [PositionReportData] = []
  @State private var selectedRows = Set<PositionReportData.ID>()
  @State private var searchText = ""

  @State private var institutions: [DatabaseManager.InstitutionData] = []
  @State private var accountTypes: [DatabaseManager.AccountTypeData] = []
  @State private var selectedInstitutionIds: Set<Int> = []
  @State private var showingDeleteSheet = false
  @State private var showDeleteSuccessToast = false
  @State private var deleteSummaryMessage = ""
  @State private var showAddSheet = false
  @State private var showEditSheet = false
  @State private var positionToEdit: PositionReportData? = nil
  @State private var positionToDelete: PositionReportData? = nil
  @State private var showDeleteSingleAlert = false
  @State private var showDeleteSelectedAlert = false
  @State private var buttonsOpacity: Double = 0

  @State private var currencyFilters: Set<String> = []

  @State private var headerOpacity: Double = 0
  @State private var contentOffset: CGFloat = 30

  @State private var sortOrder = [KeyPathComparator(\PositionReportData.accountName)]

  @StateObject private var viewModel = PositionsViewModel()

  enum Column: String, CaseIterable, Identifiable {
    case notes, account, institution, instrument, currency, quantity
    case purchase, current, valueOriginal, valueChf, dates, actions

    var id: String { rawValue }

    var title: String {
      switch self {
      case .notes: return "Notes"
      case .account: return "Account"
      case .institution: return "Institution"
      case .instrument: return "Instrument"
      case .currency: return "Currency"
      case .quantity: return "Qty"
      case .purchase: return "Purchase"
      case .current: return "Latest"
      case .valueOriginal: return "Position Value (Original Currency)"
      case .valueChf: return "Position Value (CHF)"
      case .dates: return "Dates"
      case .actions: return "Actions"
      }
    }
  }

  private static let requiredColumns: Set<Column> = [.account, .instrument]

  @AppStorage(UserDefaultsKeys.positionsVisibleColumns)
  private var persistedColumnsData: Data = Data()

  @AppStorage(UserDefaultsKeys.positionsFontSize)
  private var fontSize: Double = 13

  @State private var visibleColumns: Set<Column> = Set(Column.allCases)
  @State private var showSettingsPopover = false

  init() {
    if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.positionsVisibleColumns),
      let strings = try? JSONDecoder().decode([String].self, from: data)
    {
      let decoded = Set(strings.compactMap(Column.init(rawValue:)))
      _visibleColumns = State(initialValue: decoded.union(Self.requiredColumns))
    } else {
      _visibleColumns = State(initialValue: Set(Column.allCases))
    }
  }

  private static let chfFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.groupingSeparator = "'"
    f.usesGroupingSeparator = true
    f.roundingMode = .down
    return f
  }()

  private static let intMoneyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.minimumFractionDigits = 0
    f.groupingSeparator = "'"
    f.usesGroupingSeparator = true
    f.roundingMode = .down
    return f
  }()

  var sortedPositions: [PositionReportData] {
    filteredPositions.sorted(using: sortOrder)
  }

  var selectedInstitutionNames: [String] {
    institutions.filter { selectedInstitutionIds.contains($0.id) }.map { $0.name }
  }

  var filteredPositions: [PositionReportData] {
    viewModel.filterPositions(
      positions,
      searchText: searchText,
      selectedInstitutionNames: selectedInstitutionNames,
      currencyFilters: currencyFilters
    )
  }

  // Sum of CHF values for all rows currently displayed by filters/search
  var selectedPositionsTotalCHF: Double {
    filteredPositions.reduce(0) { sum, pos in
      if let valOpt = viewModel.positionValueCHF[pos.id], let val = valOpt { return sum + val }
      return sum
    }
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.98, green: 0.99, blue: 1.0),
          Color(red: 0.95, green: 0.97, blue: 0.99),
          Color(red: 0.93, green: 0.95, blue: 0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        modernHeader
        addButtonBar
        searchAndStats
        positionsContent
        dangerZone
      }
    }
    .onAppear {
      loadPositions()
      loadInstitutions()
      loadAccountTypes()
      viewModel.calculateValues(positions: positions, db: dbManager)
      animateEntrance()
    }
    .sheet(isPresented: $showingDeleteSheet) {
      DeletePositionsSheet(
        institutions: institutions,
        accountTypes: accountTypes,
        selectedInstitutionIds: selectedInstitutionIds,
        onConfirm: { instIds, typeIds, count in
          let deleted = dbManager.deletePositionReports(
            institutionIds: Array(instIds),
            accountTypeIds: Array(typeIds)
          )
          deleteSummaryMessage = "Deleted \(deleted) positions"
          selectedInstitutionIds.removeAll()
          loadPositions()
          showDeleteSuccessToast = true
          showingDeleteSheet = false
        },
        onCancel: { showingDeleteSheet = false }
      )
      .environmentObject(dbManager)
    }
    .alert("Delete Position", isPresented: $showDeleteSingleAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        if let p = positionToDelete {
          _ = dbManager.deletePositionReport(id: p.id)
          loadPositions()
          positionToDelete = nil
        }
      }
    } message: {
      if let p = positionToDelete {
        Text("This will permanently delete '\(p.instrumentName)' from account '\(p.accountName)'. This action cannot be undone.")
      }
    }
    .sheet(isPresented: $showAddSheet) {
      PositionFormView(position: nil) {
        loadPositions()
      }
      .environmentObject(dbManager)
    }
    .sheet(item: $positionToEdit) { item in
      PositionFormView(position: item) {
        loadPositions()
      }
      .environmentObject(dbManager)
    }
    .toast(isPresented: $viewModel.showErrorToast, message: "Failed to fetch exchange rates.")
    .toast(isPresented: $showDeleteSuccessToast, message: deleteSummaryMessage)
    .onChange(of: visibleColumns) {
      persistVisibleColumns()
    }
    .alert("Delete Selected Positions", isPresented: $showDeleteSelectedAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        let ids = Array(selectedRows)
        let deleted = dbManager.deletePositionReports(ids: ids)
        deleteSummaryMessage = "Deleted \(deleted) positions"
        showDeleteSuccessToast = true
        selectedRows.removeAll()
        loadPositions()
      }
    } message: {
      Text("This will permanently delete \(selectedRows.count) selected position(s). This action cannot be undone.")
    }
  }

  // MARK: - Modern Header
  private var modernHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 12) {
          Image(systemName: "tablecells")
            .font(.system(size: 32))
            .foregroundColor(.blue)
          Text("Positions")
            .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        Text("Current holdings with report details")
          .font(.subheadline)
          .foregroundColor(.gray)
      }
      Spacer()
      HStack(spacing: 16) {
        modernStatCard(
          title: "Total", value: "\(positions.count)", icon: "number.circle.fill", color: .blue)
        ZStack {
          modernStatCard(
            title: "Total Asset Value (CHF)",
            value: Self.chfFormatter.string(from: NSNumber(value: viewModel.totalAssetValueCHF))
              ?? "0",
            icon: "sum", color: .blue)
          if viewModel.calculating {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.black.opacity(0.1))
            ProgressView()
          }
        }
        modernStatCard(
          title: "Selected Value (CHF)",
          value: Self.chfFormatter.string(from: NSNumber(value: selectedPositionsTotalCHF)) ?? "0",
          icon: "tray.full", color: .blue)
        Button {
          viewModel.calculateValues(positions: positions, db: dbManager)
        } label: {
          Image(systemName: "arrow.clockwise")
            .padding(6)
        }
        .background(Color.blue.opacity(0.1))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.calculating)

        Button {
          showSettingsPopover.toggle()
        } label: {
          Image(systemName: "slider.horizontal.3")
            .padding(6)
        }
        .background(Color.blue.opacity(0.1))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
        .buttonStyle(ScaleButtonStyle())
        .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Columns")
              .font(.headline)
            ForEach(Column.allCases) { column in
              Toggle(
                column.title,
                isOn: Binding(
                  get: { visibleColumns.contains(column) },
                  set: { newValue in
                    if newValue {
                      visibleColumns.insert(column)
                    } else if !Self.requiredColumns.contains(column) {
                      visibleColumns.remove(column)
                    }
                  }
                )
              )
              .disabled(Self.requiredColumns.contains(column))
            }
            Divider()
            VStack(alignment: .leading) {
              Text("Font Size: \(Int(fontSize)) pt")
              Slider(value: $fontSize, in: 7...14, step: 1)
                .frame(width: 160)
            }
          }
          .padding()
          .frame(width: 220)
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 20)
    .opacity(headerOpacity)
    .offset(y: contentOffset)
  }

  private var addButtonBar: some View {
    HStack {
      Button {
        showAddSheet = true
      } label: {
        Label("Add Position", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
      .foregroundColor(.black)
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 8)
    .opacity(buttonsOpacity)
  }

  private var searchAndStats: some View {
    VStack(spacing: 12) {
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.gray)
        TextField("Search positions...", text: $searchText)
          .textFieldStyle(PlainTextFieldStyle())
        if !searchText.isEmpty {
          Button {
            searchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.gray)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.gray.opacity(0.2), lineWidth: 1)
          )
      )
      .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

      if !searchText.isEmpty || !selectedInstitutionIds.isEmpty || !currencyFilters.isEmpty {
        HStack {
          Text("Found \(filteredPositions.count) of \(positions.count) positions")
            .font(.caption)
            .foregroundColor(.gray)
          Spacer()
        }
        if !selectedInstitutionIds.isEmpty || !currencyFilters.isEmpty {
          HStack(spacing: 8) {
            ForEach(Array(selectedInstitutionIds), id: \.self) { id in
              if let inst = institutions.first(where: { $0.id == id }) {
                filterChip(text: inst.name) { selectedInstitutionIds.remove(id) }
              }
            }
            ForEach(Array(currencyFilters), id: \.self) { cur in
              filterChip(text: cur) { currencyFilters.remove(cur) }
            }
          }
        }
      }
    }
    .padding(.horizontal, 24)
    .offset(y: contentOffset)
  }

  private var positionsContent: some View {
    let data = sortedPositions
    return Table(data, selection: $selectedRows, sortOrder: $sortOrder) {
      if visibleColumns.contains(.actions) {
        TableColumn("Actions") { (position: PositionReportData) in
          HStack(spacing: 8) {
            Button(action: { positionToEdit = position }) { Image(systemName: "pencil") }
              .buttonStyle(.borderless)
            Button(action: {
              positionToDelete = position
              showDeleteSingleAlert = true
            }) { Image(systemName: "trash") }
            .buttonStyle(.borderless)
          }
          .frame(maxWidth: .infinity)
        }
        .width(min: 45, ideal: 45)
      }

      if visibleColumns.contains(.notes) {
        TableColumn("") { (position: PositionReportData) in
          if let notes = position.notes, !notes.isEmpty {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.blue)
              .help("Contains notes")
              .accessibilityLabel("Contains notes")
              .frame(width: 20)
          } else {
            Color.clear.frame(width: 20)
          }
        }
        .width(min: 24, ideal: 24)
      }

      Group {
        if visibleColumns.contains(.account) {
          TableColumn("Account", sortUsing: KeyPathComparator(\PositionReportData.accountName)) {
            (position: PositionReportData) in
            Text(position.accountName)
              .font(.system(size: fontSize))
              .foregroundColor(.secondary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
              .onTapGesture(count: 2) { positionToEdit = position }
          }
          .width(min: 160, ideal: 180)
        }

        if visibleColumns.contains(.institution) {
          TableColumn(
            "Institution", sortUsing: KeyPathComparator(\PositionReportData.institutionName)
          ) { (position: PositionReportData) in
            Text(position.institutionName)
              .font(.system(size: fontSize))
              .foregroundColor(.secondary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .width(min: 160, ideal: 180)
        }

        if visibleColumns.contains(.instrument) {
          TableColumn(
            "Instrument", sortUsing: KeyPathComparator(\PositionReportData.instrumentName)
          ) { (position: PositionReportData) in
            Text(position.instrumentName)
              .font(.system(size: fontSize))
              .foregroundColor(.primary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
              .onTapGesture(count: 2) { positionToEdit = position }
          }
          .width(min: 160, ideal: 200)
        }

        if visibleColumns.contains(.currency) {
          TableColumn(
            "Currency", sortUsing: KeyPathComparator(\PositionReportData.instrumentCurrency)
          ) { (position: PositionReportData) in
            Text(position.instrumentCurrency)
              .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
              .foregroundColor(colorForCurrency(position.instrumentCurrency))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .center)
              .onTapGesture(count: 2) { positionToEdit = position }
          }
          .width(min: 60, ideal: 70)
        }

        if visibleColumns.contains(.quantity) {
          TableColumn("Qty", sortUsing: KeyPathComparator(\PositionReportData.quantity)) {
            (position: PositionReportData) in
            Text(String(format: "%.2f", position.quantity))
              .font(.system(size: fontSize, design: .monospaced))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
          .width(min: 70, ideal: 80)
        }

        if visibleColumns.contains(.purchase) {
          TableColumn("Purchase", sortUsing: KeyPathComparator(\PositionReportData.purchasePrice)) {
            (position: PositionReportData) in
            if let p = position.purchasePrice {
              let txt = Self.intMoneyFormatter.string(from: NSNumber(value: p)) ?? String(Int(p))
              Text("\(txt) \(position.instrumentCurrency)")
                .font(.system(size: fontSize, design: .monospaced))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              Text("-")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }
          .width(min: 110, ideal: 130)
        }

        if visibleColumns.contains(.current) {
          TableColumn("Latest") { (position: PositionReportData) in
            if let id = position.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: id) {
              let txt = Self.intMoneyFormatter.string(from: NSNumber(value: lp.price)) ?? String(Int(lp.price))
              Text("\(txt) \(lp.currency)")
                .font(.system(size: fontSize, design: .monospaced))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              Text("-")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }
          .width(min: 120, ideal: 140)
        }

        if visibleColumns.contains(.valueOriginal) {
          TableColumn("Position Value (Original Currency)") { (position: PositionReportData) in
            if let value = viewModel.positionValueOriginal[position.id] {
              let txt = Self.intMoneyFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
              Text("\(txt) \(position.instrumentCurrency)")
                .font(.system(size: fontSize, design: .monospaced))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              Text("-")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }
          .width(min: 220, ideal: 240)
        }

        if visibleColumns.contains(.valueChf) {
          TableColumn("Position Value (CHF)") { (position: PositionReportData) in
            if let opt = viewModel.positionValueCHF[position.id] {
              if let value = opt {
                let txt = Self.chfFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
                Text("\(txt) CHF")
                  .font(.system(size: fontSize, design: .monospaced))
                  .lineLimit(2)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .trailing)
              } else {
                Text("-")
                  .font(.system(size: fontSize, design: .monospaced))
                  .foregroundColor(.secondary)
                  .lineLimit(2)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .trailing)
              }
            } else {
              Text("-")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }
          .width(min: 170, ideal: 190)
        }
      }

      Group {
        if visibleColumns.contains(.dates) {
          TableColumn("Dates", sortUsing: KeyPathComparator(\PositionReportData.uploadedAt)) {
            (position: PositionReportData) in
            VStack {
              if let iu = position.instrumentUpdatedAt {
                Text(iu, formatter: DateFormatter.iso8601DateOnly)
              }
              Text(position.reportDate, formatter: DateFormatter.iso8601DateOnly)
              Text(position.uploadedAt, formatter: DateFormatter.iso8601DateTime)
            }
            .font(.system(size: fontSize))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
          }
          .width(min: 120, ideal: 140)
        }
      }
    }
    .tableStyle(.inset(alternatesRowBackgrounds: true))
    .font(.system(size: fontSize))
    .padding(24)
    .background(Theme.surface)
    .cornerRadius(8)
  }

  private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View
  {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .foregroundColor(color)
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.gray)
      }
      Text(value)
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(.primary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(.regularMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(color.opacity(0.2), lineWidth: 1)
        )
    )
    .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
  }

  private var dangerZone: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(Color.gray.opacity(0.2))
        .frame(height: 1)

      HStack(spacing: 16) {
        Menu {
          ForEach(institutions, id: \.id) { inst in
            Button {
              if selectedInstitutionIds.contains(inst.id) {
                selectedInstitutionIds.remove(inst.id)
              } else {
                selectedInstitutionIds.insert(inst.id)
              }
            } label: {
              HStack {
                Text(inst.name)
                if selectedInstitutionIds.contains(inst.id) {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack {
            Text(
              selectedInstitutionIds.isEmpty
                ? "Select Institutions" : "\(selectedInstitutionIds.count) Selected"
            )
            .font(.system(size: 14, weight: .medium))
            Image(systemName: "chevron.down")
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .clipShape(Capsule())
          .overlay(
            Capsule()
              .stroke(Color.blue.opacity(0.3), lineWidth: 1)
          )
        }
        .buttonStyle(ScaleButtonStyle())

        Menu {
          ForEach(Array(Set(positions.map(\.instrumentCurrency))), id: \.self) { cur in
            Button {
              if currencyFilters.contains(cur) {
                currencyFilters.remove(cur)
              } else {
                currencyFilters.insert(cur)
              }
            } label: {
              HStack {
                Text(cur)
                if currencyFilters.contains(cur) { Image(systemName: "checkmark") }
              }
            }
          }
        } label: {
          HStack {
            Text(currencyFilters.isEmpty ? "Filter Currency" : "\(currencyFilters.count) Selected")
              .font(.system(size: 14, weight: .medium))
            Image(systemName: "chevron.down")
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .clipShape(Capsule())
          .overlay(
            Capsule()
              .stroke(Color.blue.opacity(0.3), lineWidth: 1)
          )
        }
        .buttonStyle(ScaleButtonStyle())

        Button {
          showingDeleteSheet = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "trash")
            Text("Delete by Filter…")
          }
        }
        .buttonStyle(DestructiveButtonStyle())
        .disabled(selectedInstitutionIds.isEmpty)

        Button {
          showDeleteSelectedAlert = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "trash.fill")
            Text("Delete Selected (\(selectedRows.count))")
          }
        }
        .buttonStyle(DestructiveButtonStyle())
        .disabled(selectedRows.isEmpty)

        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(Theme.surface)
    }
    .opacity(buttonsOpacity)
  }

  private func loadPositions() {
    positions = dbManager.fetchPositionReports()
    viewModel.calculateValues(positions: positions, db: dbManager)
  }

  private func loadInstitutions() {
    // Include inactive institutions to allow deleting all relevant positions.
    institutions = dbManager.fetchInstitutions(activeOnly: false)
  }

  private func loadAccountTypes() {
    // Include inactive account types so counts/deletions include all.
    accountTypes = dbManager.fetchAccountTypes(activeOnly: false)
  }

  private func animateEntrance() {
    withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
    withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
  }

  private func colorForCurrency(_ code: String) -> Color {
    switch code.uppercased() {
    case "USD": return .green
    case "CHF": return .red
    default: return .primary
    }
  }

  private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
    HStack(spacing: 4) {
      Text(text)
        .font(.caption)
      Button(action: onRemove) { Image(systemName: "xmark.circle.fill") }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.blue.opacity(0.1))
    .clipShape(Capsule())
  }

  private func persistVisibleColumns() {
    let arr = visibleColumns.map { $0.rawValue }
    if let data = try? JSONEncoder().encode(arr) {
      persistedColumnsData = data
    }
  }
}

struct DeletePositionsSheet: View {
  @EnvironmentObject var dbManager: DatabaseManager

  let institutions: [DatabaseManager.InstitutionData]
  let accountTypes: [DatabaseManager.AccountTypeData]
  let selectedInstitutionIds: Set<Int>
  var onConfirm: (Set<Int>, Set<Int>, Int) -> Void
  var onCancel: () -> Void

  @State private var instIds: Set<Int>
  @State private var typeIds: Set<Int>
  @State private var count: Int = 0

  init(
    institutions: [DatabaseManager.InstitutionData],
    accountTypes: [DatabaseManager.AccountTypeData],
    selectedInstitutionIds: Set<Int>,
    onConfirm: @escaping (Set<Int>, Set<Int>, Int) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.institutions = institutions
    self.accountTypes = accountTypes
    self.selectedInstitutionIds = selectedInstitutionIds
    self.onConfirm = onConfirm
    self.onCancel = onCancel
    _instIds = State(initialValue: selectedInstitutionIds)
    _typeIds = State(initialValue: Set(accountTypes.map { $0.id }))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Delete Positions").font(.headline)
      if !selectedInstitutionIds.isEmpty {
        Text("Institutions").font(.subheadline.weight(.semibold))
        ForEach(institutions.filter { selectedInstitutionIds.contains($0.id) }, id: \.id) { inst in
          Toggle(
            inst.name,
            isOn: Binding(
              get: { instIds.contains(inst.id) },
              set: { val in
                if val { instIds.insert(inst.id) } else { instIds.remove(inst.id) }
              }
            ))
        }
      }

      Divider()

      Text("Account Types").font(.subheadline.weight(.semibold))
      ForEach(accountTypes, id: \.id) { type in
        Toggle(
          "\(type.code) – \(type.name)",
          isOn: Binding(
            get: { typeIds.contains(type.id) },
            set: { val in
              if val { typeIds.insert(type.id) } else { typeIds.remove(type.id) }
            }
          ))
      }

      Divider()

      Text("Matching positions: \(count)")
        .font(.subheadline)
        .foregroundColor(.secondary)

      HStack {
        Spacer()
        Button("Cancel") { onCancel() }
        Button("Confirm") { onConfirm(instIds, typeIds, count) }
          .keyboardShortcut(.defaultAction)
          .disabled(count == 0)
      }
    }
    .padding(20)
    .frame(minWidth: 340)
    .onAppear { updateCount() }
    .onChange(of: instIds) { updateCount() }
    .onChange(of: typeIds) { updateCount() }
  }

  private func updateCount() {
    count = dbManager.countPositionReports(
      institutionIds: Array(instIds),
      accountTypeIds: Array(typeIds)
    )
  }
}
