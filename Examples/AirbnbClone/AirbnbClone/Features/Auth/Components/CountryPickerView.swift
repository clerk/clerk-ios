//
//  CountryPickerView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import PhoneNumberKit
import SwiftUI

struct CountryPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selectedCountry: CountryCodePickerViewController.Country

  @State private var scrolledID: String?
  var countries: [CountryCodePickerViewController.Country]

  init(selectedCountry: Binding<CountryCodePickerViewController.Country>) {
    _selectedCountry = selectedCountry
    _scrolledID = State(initialValue: selectedCountry.wrappedValue.code)

    let utility = PhoneNumberUtility()
    countries = utility
      .allCountries()
      .compactMap { CountryCodePickerViewController.Country(for: $0, with: utility) }
      .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(countries, id: \.code) { country in
            Button {
              selectedCountry = country
              dismiss()
            } label: {
              HStack {
                Text("\(country.name) (\(country.prefix))")
                  .font(.system(size: 16))
                  .foregroundStyle(.primary)

                Spacer()

                Circle()
                  .strokeBorder(
                    country.code == selectedCountry.code
                      ? Color.primary
                      : Color(uiColor: .systemGray3),
                    lineWidth: country.code == selectedCountry.code ? 6 : 1
                  )
                  .frame(width: 24, height: 24)
              }
              .padding(.horizontal, 24)
              .padding(.vertical, 16)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if country.code != countries.last?.code {
              Divider()
                .padding(.leading, 24)
            }
          }
        }
        .scrollTargetLayout()
      }
      .scrollPosition(id: $scrolledID, anchor: .center)
      .onChange(of: selectedCountry.code) { _, newCode in
        scrolledID = newCode
      }
      .navigationTitle("Country/Region")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color(uiColor: .label))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

#Preview {
  CountryPickerView(
    selectedCountry: .constant(
      CountryCodePickerViewController.Country(
        for: "US",
        with: PhoneNumberUtility()
      )!
    )
  )
}
