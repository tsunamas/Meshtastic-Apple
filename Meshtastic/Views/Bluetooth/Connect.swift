//
//  Connect.swift
//  Meshtastic Apple
//
//  Copyright(c) Garth Vander Houwen 8/18/21.
//

import SwiftUI
import MapKit
import CoreData
import CoreLocation
import CoreBluetooth
#if canImport(ActivityKit)
import ActivityKit
#endif

struct Connect: View {
	
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	@EnvironmentObject var userSettings: UserSettings
	@State var node: NodeInfoEntity? = nil
	
	@State var isPreferredRadio: Bool = false
	@State var isUnsetRegion = false
	@State var invalidFirmwareVersion = false
	@State var liveActivityStarted = false
	
	var body: some View {
		
		NavigationStack {
			VStack {
				List {
					if bleManager.isSwitchedOn {
						
						Section(header: Text("connected.radio").font(.title)) {
							if bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral.peripheral.state == .connected {
								HStack {
									Image(systemName: "antenna.radiowaves.left.and.right")
										.symbolRenderingMode(.hierarchical)
										.imageScale(.large).foregroundColor(.green)
										.padding(.trailing)
									VStack(alignment: .leading) {
										if node != nil {
											Text(bleManager.connectedPeripheral.longName).font(.title2)
										}
										Text("ble.name").font(.caption)+Text(": \(bleManager.connectedPeripheral.peripheral.name ?? NSLocalizedString("unknown", comment: "Unknown"))")
											.font(.caption).foregroundColor(Color.gray)
										if node != nil {
											Text("firmware.version").font(.caption)+Text(": \(node?.myInfo?.firmwareVersion ?? NSLocalizedString("unknown", comment: "Unknown"))")
												.font(.caption).foregroundColor(Color.gray)
										}
										if bleManager.isSubscribed {
											Text("subscribed").font(.caption)
												.foregroundColor(.green)
										} else {
											Text("communicating").font(.caption)
												.foregroundColor(.orange)
										}
									}
									Spacer()
									VStack(alignment: .center) {
										Text("preferred.radio").font(.caption2)
											.multilineTextAlignment(.center)
											.frame(width: 75)
										Toggle("preferred.radio", isOn: $bleManager.preferredPeripheral)
											.toggleStyle(SwitchToggleStyle(tint: .accentColor))
											.labelsHidden()
											.onChange(of: bleManager.preferredPeripheral) { value in
												if value {
													if bleManager.connectedPeripheral != nil {
														userSettings.preferredPeripheralId = bleManager.connectedPeripheral!.peripheral.identifier.uuidString
														userSettings.preferredNodeNum = bleManager.connectedPeripheral!.num
														bleManager.preferredPeripheral = true
														isPreferredRadio = true
													}
												} else {
													
													if bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral.peripheral.identifier.uuidString == userSettings.preferredPeripheralId {
														
														userSettings.preferredPeripheralId = ""
														userSettings.preferredNodeNum = 0
														bleManager.preferredPeripheral = false
														isPreferredRadio = false
													}
												}
											}
									}
								}
								.font(.caption).foregroundColor(Color.gray)
								.padding([.top, .bottom])
								.swipeActions {
									
									Button(role: .destructive) {
										if bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral.peripheral.state == CBPeripheralState.connected {
											bleManager.disconnectPeripheral(reconnect: false)
											isPreferredRadio = false
										}
									} label: {
										Label("disconnect", systemImage: "antenna.radiowaves.left.and.right.slash")
									}
								}
								.contextMenu{
									
									if node != nil {
										
										if #available(iOS 16.2, *) {
											Button {
												if !liveActivityStarted {
													#if canImport(ActivityKit)
													print("Start live activity.")
													startNodeActivity()
													#endif
												} else {
													#if canImport(ActivityKit)
													print("Stop live activity.")
													endActivity()
													#endif
												}
											} label: {
												Label("Mesh Live Activity", systemImage: liveActivityStarted ? "stop" : "play")
											}
										}
										Text("Num: \(String(node!.num))")
										Text("Short Name: \(node?.user?.shortName ?? "????")")
										Text("Long Name: \(node?.user?.longName ?? NSLocalizedString("unknown", comment: "Unknown"))")
										Text("Max Channels: \(String(node?.myInfo?.maxChannels ?? 0))")
										Text("Bitrate: \(String(format: "%.2f", node?.myInfo?.bitrate ?? 0.00))")
										Text("BLE RSSI: \(bleManager.connectedPeripheral.rssi)")
									}
								}
								if isUnsetRegion {
									HStack {
										NavigationLink {
											LoRaConfig(node: node)
										} label: {
											Label("set.region", systemImage: "globe.americas.fill")
												.foregroundColor(.red)
												.font(.title)
										}
									}
								}
							} else {
								
								if bleManager.isConnecting {
									HStack {
										Image(systemName: "antenna.radiowaves.left.and.right")
											.symbolRenderingMode(.hierarchical)
											.imageScale(.large).foregroundColor(.orange)
											.padding(.trailing)
										if bleManager.timeoutTimerCount == 0 {
											Text("connecting")
												.font(.title3)
												.foregroundColor(.orange)
										} else {
											VStack {
												
												Text("Connection Attempt \(bleManager.timeoutTimerCount) of 10")
													.font(.callout)
													.foregroundColor(.orange)
											}
										}
									}
									.padding()
									
								} else {
									
									if bleManager.lastConnectionError.count > 0 {
										Text(bleManager.lastConnectionError).font(.callout).foregroundColor(.red)
									}
									HStack {
										Image(systemName: "antenna.radiowaves.left.and.right.slash")
											.symbolRenderingMode(.hierarchical)
											.imageScale(.large).foregroundColor(.red)
											.padding(.trailing)
										Text("not.connected").font(.title3)
									}
									.padding()
								}
							}
						}
						.textCase(nil)
						
						if !self.bleManager.isConnected {
							Section(header: Text("available.radios").font(.title)) {
								ForEach(bleManager.peripherals.filter({ $0.peripheral.state == CBPeripheralState.disconnected }).sorted(by: { $0.name > $1.name })) { peripheral in
									HStack {
										Image(systemName: "circle.fill")
											.imageScale(.large).foregroundColor(.gray)
											.padding(.trailing)
										Button(action: {
											self.bleManager.stopScanning()
											if bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral.peripheral.state == CBPeripheralState.connected {
												
												self.bleManager.disconnectPeripheral()
											}
											self.bleManager.connectTo(peripheral: peripheral.peripheral)
											if userSettings.preferredPeripheralId == peripheral.peripheral.identifier.uuidString {
												
												isPreferredRadio = true
											} else {
												
												isPreferredRadio = false
											}
										}) {
											Text(peripheral.name).font(.title3)
										}
										Spacer()
										VStack {
											SignalStrengthIndicator(signalStrength: peripheral.getSignalStrength())
										}
									}.padding([.bottom, .top])
								}
							}.textCase(nil)
						}
						
					} else {
						Text("bluetooth.off")
							.foregroundColor(.red)
							.font(.title)
					}
				}
				
				HStack(alignment: .center) {
					Spacer()
					
					#if targetEnvironment(macCatalyst)
					
					if bleManager.connectedPeripheral != nil {
						
						Button(role: .destructive, action: {
							
							if bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral.peripheral.state == CBPeripheralState.connected {
								bleManager.disconnectPeripheral(reconnect: false)
								isPreferredRadio = false
							}
							
						}) {
							
							Label("disconnect", systemImage: "antenna.radiowaves.left.and.right.slash")
							
						}
						.buttonStyle(.bordered)
						.buttonBorderShape(.capsule)
						.controlSize(.large)
						.padding()
					}
					#endif
					Spacer()
				}
				.padding(.bottom, 10)
			}
			.navigationTitle("bluetooth")
			.navigationBarItems(leading: MeshtasticLogo(), trailing:
									ZStack {
				ConnectedDevice(bluetoothOn: bleManager.isSwitchedOn, deviceConnected: bleManager.connectedPeripheral != nil, name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName : "????")
			})
		}
		.sheet(isPresented: $invalidFirmwareVersion,  onDismiss: didDismissSheet) {
			InvalidVersion(minimumVersion: self.bleManager.minimumVersion, version: self.bleManager.connectedVersion)
				.presentationDetents([.large])
				.presentationDragIndicator(.automatic)
		}
		.onChange(of: (self.bleManager.invalidVersion)) { cv in
			invalidFirmwareVersion = self.bleManager.invalidVersion
		}
		.onChange(of: (self.bleManager.isSubscribed)) { sub in
			
			if userSettings.preferredNodeNum > 0 && sub {
				
				let fetchNodeInfoRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest.init(entityName: "NodeInfoEntity")
				fetchNodeInfoRequest.predicate = NSPredicate(format: "num == %lld", Int64(userSettings.preferredNodeNum))
				
				do {
					
					let fetchedNode = try context.fetch(fetchNodeInfoRequest) as! [NodeInfoEntity]
					// Found a node, check it for a region
					if !fetchedNode.isEmpty {
						node = fetchedNode[0]
						if node!.loRaConfig != nil && node!.loRaConfig?.regionCode ?? 0 == RegionCodes.unset.rawValue {
							isUnsetRegion = true
						} else {
							isUnsetRegion = false
						}
					}
				} catch {
					
				}
			}
		}
		.onAppear(perform: {
			self.bleManager.context = context
			self.bleManager.userSettings = userSettings
			
			// Ask for notification permission
			UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
				if success {
					print("Notifications are all set!")
				} else if let error = error {
					print(error.localizedDescription)
				}
			}
			if self.bleManager.connectedPeripheral != nil && userSettings.preferredPeripheralId == self.bleManager.connectedPeripheral.id {
				isPreferredRadio = true
			} else {
				isPreferredRadio = false
			}
		})
	}
#if canImport(ActivityKit)
func startNodeActivity() {
	if #available(iOS 16.2, *) {
		liveActivityStarted = true
		let timerSeconds = 300
		
		let mostRecent = node?.telemetries?.lastObject as! TelemetryEntity
		
		let activityAttributes = MeshActivityAttributes(nodeNum: Int(node?.num ?? 0), name: node?.user?.longName ?? "unknown")
		
		let future = Date(timeIntervalSinceNow: Double(timerSeconds))
		
		let initialContentState = MeshActivityAttributes.ContentState(timerRange: Date.now...future, connected: true, channelUtilization: mostRecent.channelUtilization, airtime: mostRecent.airUtilTx, batteryLevel: UInt32(mostRecent.batteryLevel))
		
		let activityContent = ActivityContent(state: initialContentState, staleDate: Calendar.current.date(byAdding: .minute, value: 2, to: Date())!)
		
		do {
			let myActivity = try Activity<MeshActivityAttributes>.request(attributes: activityAttributes, content: activityContent,
																		  pushType: nil)
			print(" Requested MyActivity live activity. ID: \(myActivity.id)")
		} catch let error {
			print("Error requesting live activity: \(error.localizedDescription)")
		}
	}
}

func endActivity() {
	liveActivityStarted = false
	Task {
		if #available(iOS 16.2, *) {
			for activity in Activity<MeshActivityAttributes>.activities {
				// Check if this is the activity associated with this order.
				if activity.attributes.nodeNum == node?.num ?? 0 {
					await activity.end(nil, dismissalPolicy: .immediate)
				}
			}
		}
	}
}
#endif

#if os(iOS)
func postNotification() {
	let timerSeconds = 60
	let content = UNMutableNotificationContent()
	content.title = "Mesh Live Activity Over"
	content.body = "Your timed mesh live activity is over."
	let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timerSeconds), repeats: false)
	let uuidString = UUID().uuidString
	let request = UNNotificationRequest(identifier: uuidString,
				content: content, trigger: trigger)
	let notificationCenter = UNUserNotificationCenter.current()
	notificationCenter.add(request) { (error) in
	   if error != nil {
		  // Handle any errors.
		   print("Error posting local notification: \(error?.localizedDescription ?? "no description")")
	   } else {
		   print("Posted local notification.")
	   }
	}
}
#endif
	
	func didDismissSheet() {
		bleManager.disconnectPeripheral(reconnect: false)
	}
}
