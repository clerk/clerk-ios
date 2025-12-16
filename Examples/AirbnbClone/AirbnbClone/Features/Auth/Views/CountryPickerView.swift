//
//  CountryPickerView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import PhoneNumberKit
import SwiftUI

struct CountryPickerView: View {
  typealias Country = CountryCodePickerViewController.Country

  @Environment(\.dismiss) private var dismiss
  @Binding var selectedCountry: Country

  @State private var scrolledID: String?

  private static let countries: [Country] = phoneNumberUtility
    .allCountries()
    .compactMap { Country(for: $0, with: phoneNumberUtility) }
    .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Self.countries, id: \.code) { country in
            CountryRow(
              country: country,
              isSelected: country.code == selectedCountry.code
            ) {
              selectedCountry = country
              dismiss()
            }

            if country.code != Self.countries.last?.code {
              CountryRowDivider()
            }
          }
        }
        .scrollTargetLayout()
      }
      .scrollPosition(id: $scrolledID, anchor: .center)
      .task {
        guard scrolledID == nil else { return }
        scrolledID = selectedCountry.code
      }
      .navigationTitle("Country/Region")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CountryPickerCloseButton {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - CountryRow

private struct CountryRow: View {
  let country: CountryCodePickerViewController.Country
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text("\(country.name) (\(country.prefix))")
          .font(.system(size: 16))
          .foregroundStyle(.primary)

        Spacer()

        CountrySelectionIndicator(isSelected: isSelected)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - CountrySelectionIndicator

private struct CountrySelectionIndicator: View {
  let isSelected: Bool

  var body: some View {
    Circle()
      .strokeBorder(
        isSelected ? Color.primary : Color(uiColor: .systemGray3),
        lineWidth: isSelected ? 6 : 1
      )
      .frame(width: 24, height: 24)
  }
}

// MARK: - CountryRowDivider

private struct CountryRowDivider: View {
  var body: some View {
    Divider()
      .padding(.leading, 24)
  }
}

// MARK: - CountryPickerCloseButton

private struct CountryPickerCloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(uiColor: .label))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  let country = CountryCodePickerViewController.Country(for: "US", with: phoneNumberUtility)!
  CountryPickerView(selectedCountry: .constant(country))
}
