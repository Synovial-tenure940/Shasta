//
//  PreviewViewController.swift
//  ShastaQuickLook
//

import Cocoa
import Quartz
import QuartzCore

// MARK: - PreviewViewController
class PreviewViewController: NSViewController, QLPreviewingController {
	private var rootLayer: CALayer?
	private var stateController: CAStateController?
	private var cycleTimer: Timer?
	private var states: [Any] = []
	private var currentStateIndex: Int? = nil

	override var nibName: NSNib.Name? { nil }

	override func loadView() {
		let v = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 800))
		v.wantsLayer = true
		self.view = v
	}

	func preparePreviewOfFile(at url: URL) async throws {
		let type: String = url.pathExtension == "ca"
			? kCAPackageTypeCAMLBundle
			: kCAPackageTypeArchive
		
		guard let package = try CAPackage.package(
			withContentsOf: url,
			type: type,
			options: nil
		) as? CAPackage else {
			throw NSError(
				domain: "ShastaQuickLook", code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Failed to load CAPackage"]
			)
		}

		guard let root = package.rootLayer else {
			return
		}

		await MainActor.run {
			self.rootLayer = root

			root.anchorPoint = CGPoint(x: 0.5, y: 0.5)
			if package.isGeometryFlipped {
				root.setValue(true, forKey: "geometryFlipped")
			}

			view.layer?.addSublayer(root)
			fitLayer(root, in: view.bounds)

			let sc = CAStateController(layer: root)
			sc?.setInitialStatesOfLayer(root, transitionSpeed: 0.0)
			self.stateController = sc

			if let s = root.value(forKey: "states") as? [Any], !s.isEmpty {
				self.states = s
			}

			startCycling()
		}
	}

	override func viewDidLayout() {
		super.viewDidLayout()
		
		if let root = rootLayer {
			fitLayer(root, in: view.bounds)
		}
	}

	private func fitLayer(_ layer: CALayer, in bounds: CGRect) {
		let ls = layer.bounds.size
		guard ls.width > 0, ls.height > 0, bounds.width > 0, bounds.height > 0 else { return }
		let scale = min(bounds.width / ls.width, bounds.height / ls.height) * 0.9
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
		layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		CATransaction.commit()
	}

	private func startCycling() {
		guard !states.isEmpty else { return }
		advanceState()
		cycleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			self?.advanceState()
		}
	}

	private func advanceState() {
		guard let sc = stateController, let root = rootLayer else { return }
		if let current = currentStateIndex {
			let next = current + 1 < states.count ? current + 1 : nil
			currentStateIndex = next
			sc.setState(next.map { states[$0] } ?? nil, ofLayer: root, transitionSpeed: 1.0)
		} else {
			currentStateIndex = 0
			sc.setState(states[0], ofLayer: root, transitionSpeed: 1.0)
		}
	}

	deinit {
		cycleTimer?.invalidate()
	}
}
