import Foundation
import Combine
import SwiftUI
import SwiftProtobuf
import MapKit

struct AppSettings: View {
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	@ObservedObject var tileManager = OfflineTileManager.shared
	@State var totalDownloadedTileSize = ""
	@StateObject var locationHelper = LocationHelper()
	@State var meshtasticUsername: String = UserDefaults.meshtasticUsername
	@State var provideLocation: Bool = UserDefaults.provideLocation
	@State var blockRangeTest: Bool = UserDefaults.blockRangeTest
	@State var useLegacyMap: Bool = UserDefaults.mapUseLegacy
	@State var provideLocationInterval: Int = UserDefaults.provideLocationInterval
	@State private var isPresentingCoreDataResetConfirm = false
	@State private var isPresentingDeleteMapTilesConfirm = false
	var body: some View {
		VStack {
			Form {
				Section(header: Text("user.details")) {
					HStack {
						Label("Name", systemImage: "person.crop.rectangle.fill")
						TextField("Username", text: $meshtasticUsername)
							.foregroundColor(.gray)
					}
					.keyboardType(.asciiCapable)
					.disableAutocorrection(true)
					.listRowSeparator(.visible)
				}
				Section(header: Text("options")) {
					
					Toggle(isOn: $blockRangeTest) {
						Label("range.test.blocked", systemImage: "x.circle")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					
					Toggle(isOn: $useLegacyMap) {
						Label("map.use.legacy", systemImage: "map")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				}
				Section(header: Text("phone.gps")) {
					let accuracy = Measurement(value: locationHelper.locationManager.location?.horizontalAccuracy ?? 300, unit: UnitLength.meters)
					let altitiude = Measurement(value: locationHelper.locationManager.location?.altitude ?? 0, unit: UnitLength.meters)
					let speed = Measurement(value: locationHelper.locationManager.location?.speed ?? 0, unit: UnitSpeed.kilometersPerHour)
					HStack {
						Label("Accuracy \(accuracy.formatted())", systemImage: "scope")
							.font(.footnote)
						Label("Sats \(LocationHelper.satsInView)", systemImage: "sparkles")
							.font(.footnote)
					}
					Label("Coordinate \(String(format: "%.5f", locationHelper.locationManager.location?.coordinate.latitude ?? 0)), \(String(format: "%.5f", locationHelper.locationManager.location?.coordinate.longitude ?? 0))", systemImage: "mappin")
						.font(.footnote)
						.textSelection(.enabled)
					if locationHelper.locationManager.location?.verticalAccuracy ?? 0 > 0 {
						Label("Altitude \(altitiude.formatted())", systemImage: "mountain.2")
							.font(.footnote)
					}
					if locationHelper.locationManager.location?.courseAccuracy ?? 0 > 0 {
						Label("Heading \(String(format: "%.2f", locationHelper.locationManager.location?.course ?? 0))°", systemImage: "location.circle")
							.font(.footnote)
					}
					if locationHelper.locationManager.location?.speedAccuracy ?? 0 > 0 {
						Label("Speed \(speed.formatted())", systemImage: "speedometer")
							.font(.footnote)
					}
				}
				Section(header: Text("Location Settings")) {
					Toggle(isOn: $provideLocation) {
						Label("provide.location", systemImage: "location.circle.fill")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					if UserDefaults.provideLocation {
						VStack {
							Picker("update.interval", selection: $provideLocationInterval) {
								ForEach(LocationUpdateInterval.allCases) { lu in
									Text(lu.description)
								}
							}
							.pickerStyle(DefaultPickerStyle())
							.onChange(of: (provideLocationInterval)) { newProvideLocationInterval in
								UserDefaults.provideLocationInterval = newProvideLocationInterval
							}
							Text("phone.gps.interval.description")
								.font(.caption2)
								.foregroundColor(.gray)
						}
					}
				}
				Section(header: Text("App Data")) {
					Button {
						isPresentingCoreDataResetConfirm = true
					} label: {
						Label("clear.app.data", systemImage: "trash")
							.foregroundColor(.red)
					}
					.confirmationDialog(
						"are.you.sure",
						isPresented: $isPresentingCoreDataResetConfirm,
						titleVisibility: .visible
					) {
						Button("Erase all app data?", role: .destructive) {
							bleManager.disconnectPeripheral()
							clearCoreDataDatabase(context: context)
							UserDefaults.standard.reset()
							UserDefaults.standard.synchronize()
						}
					}
				}
				if totalDownloadedTileSize != "0MB" {
					Section(header: Text("Map Tile Data")) {
						Button {
							isPresentingDeleteMapTilesConfirm = true
						} label: {
							Label("\("map.tiles.delete".localized) (\(totalDownloadedTileSize))", systemImage: "trash")
								.foregroundColor(.red)
						}
						.confirmationDialog(
							"are.you.sure",
							isPresented: $isPresentingDeleteMapTilesConfirm,
							titleVisibility: .visible
						) {
							Button("Delete all map tiles?", role: .destructive) {
								tileManager.removeAll()
								totalDownloadedTileSize = tileManager.getAllDownloadedSize()
								print("delete all tiles")
							}
						}
					}
				}
			}
			.onAppear(perform: {
				totalDownloadedTileSize = tileManager.getAllDownloadedSize()
			})
		}
		.navigationTitle("app.settings")
		.navigationBarItems(trailing:
								ZStack {
			ConnectedDevice(bluetoothOn: bleManager.isSwitchedOn, deviceConnected: bleManager.connectedPeripheral != nil, name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName : "?")
		})
		.onAppear {
			self.bleManager.context = context
		}
		.onChange(of: blockRangeTest) { newBlockRangeTest in
			UserDefaults.blockRangeTest = newBlockRangeTest
		}
		.onChange(of: (meshtasticUsername)) { newMeshtasticUsername in
			UserDefaults.meshtasticUsername = newMeshtasticUsername
		}
		.onChange(of: provideLocation) { newProvideLocation in
			UserDefaults.provideLocation = newProvideLocation
			if bleManager.connectedPeripheral != nil {
				self.bleManager.sendWantConfig()
			}
		}
		.onChange(of: useLegacyMap) { newMapUseLegacy in
			UserDefaults.mapUseLegacy = newMapUseLegacy
		}
	}
}
