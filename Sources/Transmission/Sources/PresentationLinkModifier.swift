//
// Copyright (c) Nathan Tannar
//

#if os(iOS)

import SwiftUI
import Engine
import EngineCore
import Turbocharger

/// A modifier that presents a destination view in a new `UIViewController`.
///
/// To present the destination view with an animation, `isPresented` should
/// be updated with a transaction that has an animation. For example:
///
/// ```
/// withAnimation {
///     isPresented = true
/// }
/// ```
///
/// The destination view is presented with the provided `transition`.
/// By default, the ``PresentationLinkTransition/default`` transition is used.
///
/// See Also:
///  - ``PresentationLinkTransition``
///  - ``TransitionReader``
///
/// > Tip: You can implement custom transitions with a `UIPresentationController` and/or
/// `UIViewControllerInteractiveTransitioning` with the ``PresentationLinkTransition/custom(_:)``
///  transition.
///
@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@frozen
public struct PresentationLinkModifier<
    Destination: View
>: ViewModifier {

    var isPresented: Binding<Bool>
    var destination: Destination
    var transition: PresentationLinkTransition

    public init(
        transition: PresentationLinkTransition = .default,
        isPresented: Binding<Bool>,
        destination: Destination
    ) {
        self.isPresented = isPresented
        self.destination = destination
        self.transition = transition
    }

    public func body(content: Content) -> some View {
        content.background(
            PresentationLinkModifierBody(
                transition: transition,
                isPresented: isPresented,
                destination: destination
            )
        )
    }
}

@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension View {
    /// A modifier that presents a destination view in a new `UIViewController`.
    ///
    /// To present the destination view with an animation, `isPresented` should
    /// be updated with a transaction that has an animation. For example:
    ///
    /// ```
    /// withAnimation {
    ///     isPresented = true
    /// }
    /// ```
    ///
    /// See Also:
    ///  - ``PresentationLinkModifier``
    ///
    public func presentation<Destination: View>(
        transition: PresentationLinkTransition = .default,
        isPresented: Binding<Bool>,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        modifier(
            PresentationLinkModifier(
                transition: transition,
                isPresented: isPresented,
                destination: destination()
            )
        )
    }

    /// A modifier that presents a destination view in a new `UIViewController`.
    ///
    /// To present the destination view with an animation, `isPresented` should
    /// be updated with a transaction that has an animation. For example:
    ///
    /// ```
    /// withAnimation {
    ///     isPresented = true
    /// }
    /// ```
    ///
    /// See Also:
    ///  - ``PresentationLinkModifier``
    ///  
    public func presentation<T, Destination: View>(
        _ value: Binding<T?>,
        transition: PresentationLinkTransition = .default,
        @ViewBuilder destination: (Binding<T>) -> Destination
    ) -> some View {
        presentation(transition: transition, isPresented: value.isNotNil()) {
            OptionalAdapter(value, content: destination)
        }
    }

    /// A modifier that presents a destination `UIViewController`.
    ///
    /// To present the destination view with an animation, `isPresented` should
    /// be updated with a transaction that has an animation. For example:
    ///
    /// ```
    /// withAnimation {
    ///     isPresented = true
    /// }
    /// ```
    /// 
    /// See Also:
    ///  - ``PresentationLinkModifier``
    ///
    @_disfavoredOverload
    public func presentation<ViewController: UIViewController>(
        transition: PresentationLinkTransition = .default,
        isPresented: Binding<Bool>,
        destination: @escaping (_ViewControllerRepresentableAdapter<ViewController>.Context) -> ViewController
    ) -> some View {
        presentation(transition: transition, isPresented: isPresented) {
            _ViewControllerRepresentableAdapter(makeUIViewController: destination)
        }
    }
}

@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
private struct PresentationLinkModifierBody<
    Destination: View
>: UIViewRepresentable {

    var transition: PresentationLinkTransition
    var isPresented: Binding<Bool>
    var destination: Destination

    @WeakState var presentingViewController: UIViewController?

    typealias DestinationViewController = HostingController<ModifiedContent<Destination, PresentationBridgeAdapter>>

    func makeUIView(context: Context) -> ViewControllerReader {
        let uiView = ViewControllerReader(
            presentingViewController: $presentingViewController
        )
        return uiView
    }

    func updateUIView(_ uiView: ViewControllerReader, context: Context) {
        if let presentingViewController = presentingViewController, isPresented.wrappedValue {

            context.coordinator.isPresented = isPresented

            let traits = UITraitCollection(traitsFrom: [
                presentingViewController.traitCollection,
                UITraitCollection(userInterfaceStyle: .init(context.environment.colorScheme)),
                UITraitCollection(layoutDirection: .init(context.environment.layoutDirection)),
                UITraitCollection(verticalSizeClass: .init(context.environment.verticalSizeClass)),
                UITraitCollection(horizontalSizeClass: .init(context.environment.horizontalSizeClass)),
                UITraitCollection(accessibilityContrast: .init(context.environment.colorSchemeContrast)),
                UITraitCollection(legibilityWeight: .init(context.environment.legibilityWeight)),
                UITraitCollection(displayScale: context.environment.displayScale),
                UITraitCollection(activeAppearance: .unspecified),
                UITraitCollection(userInterfaceLevel: .elevated)
            ])

            let isPresented = Binding<Bool>(
                get: { true },
                set: { newValue, transaction in
                    if !newValue {
                        let isAnimated = transaction.isAnimated || PresentationCoordinator.transaction.isAnimated
                        context.coordinator.adapter?.viewController?.dismiss(animated: isAnimated)
                    }
                }
            )

            let isAnimated = context.transaction.isAnimated || (presentingViewController.transitionCoordinator?.isAnimated ?? false)
            if let adapter = context.coordinator.adapter, !context.coordinator.isBeingReused {

                
                switch (adapter.transition, transition.value) {
                case (.sheet(let oldValue), .sheet(let newValue)):
                    adapter.transition = .sheet(newValue)

                    guard #available(iOS 15.0, *), let presentationController = adapter.viewController.presentationController as? SheetPresentationController
                    else {
                        break
                    }
                    PresentationLinkTransition.SheetTransitionOptions.update(
                        presentationController: presentationController,
                        animated: isAnimated,
                        from: oldValue,
                        to: newValue
                    )

                case (.popover(let oldValue), .popover(let newValue)):
                    adapter.transition = .popover(newValue)

                    if let presentationController = adapter.viewController.presentationController as? UIPopoverPresentationController {
                        presentationController.permittedArrowDirections = newValue.permittedArrowDirections(
                            layoutDirection: traits.layoutDirection
                        )
                        presentationController.backgroundColor = newValue.options.preferredPresentationBackgroundUIColor
                    } else if #available(iOS 15.0, *) {
                        if let newValue = newValue.adaptiveTransition,
                            let presentationController = adapter.viewController.presentationController as? SheetPresentationController
                        {
                            PresentationLinkTransition.SheetTransitionOptions.update(
                                presentationController: presentationController,
                                animated: isAnimated,
                                from: oldValue.adaptiveTransition ?? .init(),
                                to: newValue
                            )
                        }
                    }

                case (.slide(let oldValue), .slide(let newValue)):
                    adapter.transition = .slide(newValue)

                    if oldValue.edge != newValue.edge,
                        let presentationController = adapter.viewController.presentationController as? SlidePresentationController
                    {
                        presentationController.edge = newValue.edge
                    }

                default:
                    adapter.transition = transition.value
                }

                adapter.viewController.presentationController?.overrideTraitCollection = traits

                adapter.update(
                    destination: destination,
                    isPresented: isPresented,
                    sourceView: uiView,
                    context: context
                )
            } else {
                let adapter: PresentationLinkDestinationViewControllerAdapter<Destination>
                if let oldValue = context.coordinator.adapter {
                    adapter = oldValue
                    adapter.transition = transition.value
                    adapter.update(
                        destination: destination,
                        isPresented: isPresented,
                        sourceView: uiView,
                        context: context
                    )
                    context.coordinator.isBeingReused = false
                } else {
                    adapter = PresentationLinkDestinationViewControllerAdapter(
                        destination: destination,
                        isPresented: isPresented,
                        sourceView: uiView,
                        transition: transition.value,
                        context: context
                    )
                    context.coordinator.adapter = adapter
                }

                switch adapter.transition {
                case .`default`:
                    break
                case .fullscreen, .currentContext, .sheet, .popover, .slide, .custom:
                    adapter.viewController.transitioningDelegate = context.coordinator
                }

                switch adapter.transition {
                case .currentContext:
                    // transitioningDelegate + .custom breaks .overCurrentContext
                    adapter.viewController.modalPresentationStyle = .overCurrentContext
                    adapter.viewController.presentationController?.overrideTraitCollection = traits

                case .fullscreen, .sheet, .popover, .`default`:
                    switch adapter.transition {
                    case .fullscreen:
                        adapter.viewController.modalPresentationStyle = .overFullScreen

                    case .`default`:
                        break

                    default:
                        adapter.viewController.modalPresentationStyle = .custom
                    }

                    if let presentationController = adapter.viewController.presentationController {
                        presentationController.delegate = context.coordinator
                        presentationController.overrideTraitCollection = traits

                        if #available(iOS 15.0, *),
                           let sheetPresentationController = presentationController as? UISheetPresentationController
                        {
                            sheetPresentationController.delegate = context.coordinator
                            if case .sheet(let options) = adapter.transition,
                                options.prefersSourceViewAlignment
                            {
                                sheetPresentationController.sourceView = uiView
                            }
                        } else if let popoverPresentationController = presentationController as? UIPopoverPresentationController {
                            popoverPresentationController.delegate = context.coordinator
                            popoverPresentationController.sourceView = uiView
                            if case .popover(let options) = adapter.transition {
                                let permittedArrowDirections = options.permittedArrowDirections(
                                    layoutDirection: traits.layoutDirection
                                )
                                popoverPresentationController.permittedArrowDirections = permittedArrowDirections
                                popoverPresentationController.backgroundColor = options.options.preferredPresentationBackgroundUIColor
                            }
                        }
                    }

                case .slide:
                    adapter.viewController.modalPresentationStyle = .custom

                case .custom(_, let transition):
                    assert(!isClassType(transition), "PresentationLinkCustomTransition must be value types (either a struct or an enum); it was a class")
                    context.coordinator.sourceView = uiView
                    adapter.viewController.modalPresentationStyle = .custom
                    adapter.viewController.presentationController?.overrideTraitCollection = traits
                }

                // Swizzle to hook up for programatic dismissal
                adapter.viewController.presentationDelegate = context.coordinator

                if let presentedViewController = presentingViewController.presentedViewController {
                    let shouldDismiss = presentedViewController.presentationController.map {
                        $0.delegate?.presentationControllerShouldDismiss?($0) ?? true
                    } ?? true
                    if shouldDismiss {
                        presentingViewController.dismiss(animated: isAnimated) {
                            presentingViewController.present(adapter.viewController, animated: isAnimated)
                        }
                    } else {
                        withCATransaction {
                            isPresented.wrappedValue = false
                        }
                    }
                } else {
                    presentingViewController.present(adapter.viewController, animated: isAnimated)
                }
            }
        } else if let adapter = context.coordinator.adapter,
            !isPresented.wrappedValue,
            !context.coordinator.isBeingReused
        {
            let isAnimated = context.transaction.isAnimated || PresentationCoordinator.transaction.isAnimated
            let viewController = adapter.viewController!
            if viewController.presentedViewController != nil {
                (viewController.presentingViewController ?? viewController).dismiss(animated: isAnimated) {
                    PresentationCoordinator.transaction = nil
                }
            } else {
                viewController.dismiss(animated: isAnimated) {
                    PresentationCoordinator.transaction = nil
                }
            }
            if adapter.transition.options.isDestinationReusable {
                context.coordinator.isBeingReused = true
            } else {
                context.coordinator.adapter = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: isPresented)
    }

    final class Coordinator: NSObject,
        UIViewControllerTransitioningDelegate,
        UIAdaptivePresentationControllerDelegate,
        UISheetPresentationControllerDelegate,
        UIPopoverPresentationControllerDelegate,
        UIViewControllerPresentationDelegate
    {
        var isPresented: Binding<Bool>
        var adapter: PresentationLinkDestinationViewControllerAdapter<Destination>?
        var isBeingReused = false
        unowned var sourceView: UIView!

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        // MARK: - UIViewControllerPresentationDelegate

        func viewControllerDidDismiss() {
            withCATransaction {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.isPresented.wrappedValue = false
                }
            }
        }

        // MARK: - UIAdaptivePresentationControllerDelegate

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            if let toView = presentationController.presentingViewController.viewIfLoaded {
                // This fixes SwiftUI's gesture handling that can get messed up when applying
                // transforms and/or frame changes during an interactive presentation. This resets
                // SwiftUI's geometry in a clean way, fixing hit testing.
                let frame = toView.frame
                toView.frame = .zero
                toView.frame = frame
            }
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            switch adapter?.transition {
            case .sheet(let options):
                return options.isInteractive

            case .popover(let options):
                return options.isInteractive

            case .slide(let options):
                return options.isInteractive

            default:
                return true
            }
        }

        func presentationControllerDidAttemptToDismiss(
            _ presentationController: UIPresentationController
        ) {
            if let fromView = presentationController.presentedViewController.viewIfLoaded {
                // This fixes SwiftUI's gesture handling that can get messed up when applying
                // transforms and/or frame changes during an interactive presentation. This resets
                // SwiftUI's geometry in a clean way, fixing hit testing.
                let frame = fromView.frame
                fromView.frame = .zero
                fromView.frame = frame
            }
        }

        func adaptivePresentationStyle(
            for controller: UIPresentationController
        ) -> UIModalPresentationStyle {
            adaptivePresentationStyle(for: controller, traitCollection: controller.traitCollection)
        }

        func adaptivePresentationStyle(
            for controller: UIPresentationController,
            traitCollection: UITraitCollection
        ) -> UIModalPresentationStyle {
            switch adapter?.transition {
            case .popover(let options):
                return options.adaptiveTransition != nil && traitCollection.horizontalSizeClass == .compact ? .pageSheet : .none

            case .custom(_, let transition):
                return transition.adaptivePresentationStyle(for: controller, traitCollection: traitCollection)

            default:
                return .none
            }
        }

        func presentationController(
            _ presentationController: UIPresentationController,
            prepare adaptivePresentationController: UIPresentationController
        ) {
            switch adapter?.transition {
            case .popover(let options):
                if #available(iOS 15.0, *) {
                    if let options = options.adaptiveTransition,
                        let presentationController = adaptivePresentationController as? SheetPresentationController
                    {
                        PresentationLinkTransition.SheetTransitionOptions.update(
                            presentationController: presentationController,
                            animated: false,
                            from: .init(),
                            to: options
                        )
                    }
                }

            case .custom(_, let transition):
                transition.presentationController(presentationController, prepare: adaptivePresentationController)

            default:
                break
            }
        }

        // MARK: - UIViewControllerTransitioningDelegate

        func animationController(
            forPresented presented: UIViewController,
            presenting: UIViewController,
            source: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            switch adapter?.transition {
            case .sheet(let options):
                #if targetEnvironment(macCatalyst)
                if #available(iOS 15.0, *) {
                    let transition = SlideTransition(
                        isPresenting: true,
                        options: .init(
                            edge: .bottom,
                            prefersScaleEffect: false,
                            preferredCornerRadius: options.preferredCornerRadius,
                            isInteractive: options.isInteractive,
                            options: options.options
                        )
                    )
                    transition.wantsInteractiveStart = false
                    return transition
                }
                #endif
                return nil

            case .slide(let options):
                let transition = SlideTransition(
                    isPresenting: true,
                    options: options
                )
                transition.wantsInteractiveStart = false
                return transition

            case .custom(_, let transition):
                return transition.animationController(
                    forPresented: presented,
                    presenting: presenting
                )

            default:
                return nil
            }
        }

        func animationController(
            forDismissed dismissed: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            switch adapter?.transition {
            case .sheet(let options):
                #if targetEnvironment(macCatalyst)
                if #available(iOS 15.0, *),
                    let presentationController = dismissed.presentationController as? MacSheetPresentationController
                {
                    let transition = SlideTransition(
                        isPresenting: false,
                        options: .init(
                            edge: .bottom,
                            prefersScaleEffect: false,
                            preferredCornerRadius: options.preferredCornerRadius,
                            isInteractive: options.isInteractive,
                            options: options.options
                        )
                    )
                    presentationController.begin(transition: transition, isInteractive: options.isInteractive)
                    return transition
                }
                #endif
                return nil

            case .slide(let options):
                guard let presentationController = dismissed.presentationController as? SlidePresentationController else {
                    return nil
                }
                let transition = SlideTransition(
                    isPresenting: false,
                    options: options
                )
                transition.wantsInteractiveStart = options.isInteractive
//                presentationController.begin(transition: transition, isInteractive: options.isInteractive)
                return transition

            case .custom(_, let transition):
                return transition.animationController(forDismissed: dismissed)

            default:
                return nil
            }
        }

        func interactionControllerForPresentation(
            using animator: UIViewControllerAnimatedTransitioning
        ) -> UIViewControllerInteractiveTransitioning? {
            switch adapter?.transition {
            case .custom(_, let transition):
                return transition.interactionControllerForPresentation(using: animator)

            default:
                return nil
            }
        }

        func interactionControllerForDismissal(
            using animator: UIViewControllerAnimatedTransitioning
        ) -> UIViewControllerInteractiveTransitioning? {
            switch adapter?.transition {
            case .sheet:
                #if targetEnvironment(macCatalyst)
                if #available(iOS 15.0, *) {
                    return animator as? SlideTransition
                }
                #endif
                return nil

            case .slide:
                return animator as? SlideTransition

            case .custom(_, let transition):
                return transition.interactionControllerForDismissal(using: animator)

            default:
                return nil
            }
        }

        func presentationController(
            forPresented presented: UIViewController,
            presenting: UIViewController?,
            source: UIViewController
        ) -> UIPresentationController? {
            switch adapter?.transition {
            case .sheet(let configuration):
                if #available(iOS 15.0, *) {
                    #if targetEnvironment(macCatalyst)
                    let presentationController = MacSheetPresentationController(
                        presentedViewController: presented,
                        presenting: presenting
                    )
                    presentationController.preferredCornerRadius = configuration.preferredCornerRadius
                    let selected = configuration.selected?.wrappedValue
                    presentationController.detent = configuration.detents.first(where: { $0.identifier == selected }) ?? configuration.detents.first ?? .large
                    presentationController.selected = configuration.selected
                    presentationController.largestUndimmedDetentIdentifier = configuration.largestUndimmedDetentIdentifier
                    return presentationController
                    #else
                    let presentationController = SheetPresentationController(
                        presentedViewController: presented,
                        presenting: presenting
                    )
                    presentationController.detents = configuration.detents.map { $0.resolve(in: presentationController).toUIKit() }
                    presentationController.selectedDetentIdentifier = (configuration.selected?.wrappedValue ?? configuration.detents.first?.identifier)?.toUIKit()
                    presentationController.largestUndimmedDetentIdentifier = configuration.largestUndimmedDetentIdentifier?.toUIKit()
                    presentationController.prefersGrabberVisible = configuration.prefersGrabberVisible
                    presentationController.preferredCornerRadius = configuration.preferredCornerRadius
                    presentationController.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
                    presentationController.prefersEdgeAttachedInCompactHeight = configuration.prefersEdgeAttachedInCompactHeight
                    presentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = configuration.widthFollowsPreferredContentSizeWhenEdgeAttached
                    presentationController.delegate = self
                    return presentationController
                    #endif
                } else {
                    // Fallback on earlier versions
                    let presentationController = PresentationController(
                        presentedViewController: presented,
                        presenting: presenting
                    )
                    presentationController.delegate = self
                    return presentationController
                }

            case .popover(let options):
                let presentationController = UIPopoverPresentationController(
                    presentedViewController: presented,
                    presenting: presenting
                )
                presentationController.canOverlapSourceViewRect = options.canOverlapSourceViewRect
                presentationController.permittedArrowDirections = options.permittedArrowDirections(
                    layoutDirection: presentationController.traitCollection.layoutDirection
                )
                presentationController.delegate = self
                return presentationController

            case .slide(let options):
                let presentationController = SlidePresentationController(
                    presentedViewController: presented,
                    presenting: presenting
                )
                presentationController.edge = options.edge
                presentationController.delegate = self
                return presentationController

            case .custom(_, let transition):
                let presentationController = transition.presentationController(
                    sourceView: sourceView,
                    presented: presented,
                    presenting: presenting
                )
                presentationController.delegate = self
                return presentationController

            default:
                return nil
            }
        }

        func presentationController(
            _ presentationController: UIPresentationController,
            willPresentWithAdaptiveStyle style: UIModalPresentationStyle,
            transitionCoordinator: UIViewControllerTransitionCoordinator?
        ) {
            #if !targetEnvironment(macCatalyst)
            if #available(iOS 15.0, *) {
                if let sheetPresentationController = presentationController as? SheetPresentationController {
                    transitionCoordinator?.animate(alongsideTransition: { _ in
                        self.sheetPresentationControllerDidChangeSelectedDetentIdentifier(sheetPresentationController)
                    })
                }
            }
            #endif
        }

        // MARK: - UISheetPresentationControllerDelegate

        @available(iOS 15.0, *)
        @available(macOS, unavailable)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
            _ sheetPresentationController: UISheetPresentationController
        ) {
            if case .sheet(let configuration) = adapter?.transition {
                func applySelection() {
                    configuration.selected?.wrappedValue = sheetPresentationController.selectedDetentIdentifier.map {
                        .init($0.rawValue)
                    }
                }

                if sheetPresentationController.selectedDetentIdentifier?.rawValue == PresentationLinkTransition.SheetTransitionOptions.Detent.ideal.identifier.rawValue {
                    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
                        sheetPresentationController.invalidateDetents()
                        applySelection()
                    } else {
                        sheetPresentationController.detents = configuration.detents.map { $0.resolve(in: sheetPresentationController).toUIKit() }
                        withCATransaction {
                            applySelection()
                        }
                    }
                } else {
                    applySelection()
                }
            }
        }

        // MARK: - UIPopoverPresentationControllerDelegate

        func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
            popoverPresentationController.presentedViewController.view.layoutIfNeeded()
        }
    }

    static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator) {
        coordinator.adapter?.viewController.dismiss(animated: false)
        coordinator.adapter = nil
    }
}

@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
private class PresentationLinkDestinationViewControllerAdapter<
    Destination: View
> {

    typealias DestinationController = HostingController<ModifiedContent<Destination, PresentationBridgeAdapter>>

    var viewController: UIViewController!
    var context: Any!

    var transition: PresentationLinkTransition.Value
    var conformance: ProtocolConformance<UIViewControllerRepresentableProtocolDescriptor>? = nil

    init(
        destination: Destination,
        isPresented: Binding<Bool>,
        sourceView: UIView,
        transition: PresentationLinkTransition.Value,
        context: PresentationLinkModifierBody<Destination>.Context
    ) {
        self.transition = transition
        if let conformance = UIViewControllerRepresentableProtocolDescriptor.conformance(of: Destination.self) {
            self.conformance = conformance
            update(
                destination: destination,
                isPresented: isPresented,
                sourceView: sourceView,
                context: context
            )
        } else {
            let viewController = DestinationController(
                content: destination.modifier(
                    PresentationBridgeAdapter(
                        isPresented: isPresented
                    )
                )
            )
            transition.update(viewController)
            self.viewController = viewController
        }
    }

    deinit {
        switch transition {
        case .sheet(let configuration):
            withCATransaction {
                configuration.selected?.wrappedValue = nil
            }
        default:
            break
        }
        if let conformance = conformance {
            var visitor = Visitor(
                destination: nil,
                isPresented: .constant(false),
                sourceView: nil,
                context: nil,
                adapter: self
            )
            conformance.visit(visitor: &visitor)
        }
    }

    func update(
        destination: Destination,
        isPresented: Binding<Bool>,
        sourceView: UIView,
        context: PresentationLinkModifierBody<Destination>.Context
    ) {
        if let conformance = conformance {
            var visitor = Visitor(
                destination: destination,
                isPresented: isPresented,
                sourceView: sourceView,
                context: context,
                adapter: self
            )
            conformance.visit(visitor: &visitor)
            if case .custom(let options, _) = transition {
                viewController.modalPresentationCapturesStatusBarAppearance = options.modalPresentationCapturesStatusBarAppearance
            }
        } else {
            let viewController = viewController as! DestinationController
            viewController.content = destination.modifier(
                PresentationBridgeAdapter(
                    isPresented: isPresented
                )
            )
            transition.update(viewController)
        }
    }

    private struct Context<Coordinator> {
        var coordinator: Coordinator
        var transaction: Transaction
        var environment: EnvironmentValues
        var preferenceBridge: AnyObject?
    }

    private struct Visitor: ViewVisitor {
        var destination: Destination?
        var isPresented: Binding<Bool>
        var sourceView: UIView?
        var context: PresentationLinkModifierBody<Destination>.Context?
        var adapter: PresentationLinkDestinationViewControllerAdapter<Destination>

        mutating func visit<Content>(type: Content.Type) where Content: UIViewControllerRepresentable {
            guard
                let destination = destination.map({ unsafeBitCast($0, to: Content.self) }),
                let context = context
            else {
                if let context = adapter.context, let viewController = adapter.viewController as? Content.UIViewControllerType {
                    func project<T>(_ value: T) {
                        let coordinator = unsafeBitCast(value, to: Content.Context.self).coordinator
                        Content.dismantleUIViewController(viewController, coordinator: coordinator)
                    }
                    _openExistential(context, do: project)
                }
                return
            }
            if adapter.context == nil {
                let preferenceBridge = unsafeBitCast(
                    context,
                    to: Context<PresentationLinkModifierBody<Destination>.Coordinator>.self
                ).preferenceBridge
                let context = Context(
                    coordinator: destination.makeCoordinator(),
                    transaction: context.transaction,
                    environment: context.environment,
                    preferenceBridge: preferenceBridge
                )
                adapter.context = unsafeBitCast(context, to: Content.Context.self)
            }
            func project<T>(_ value: T) -> Content.Context {
                var ctx = unsafeBitCast(value, to: Context<Content.Coordinator>.self)
                let isPresented = self.isPresented
                ctx.environment.presentationCoordinator = PresentationCoordinator(
                    isPresented: isPresented.wrappedValue,
                    sourceView: sourceView,
                    dismissBlock: {
                        isPresented.wrappedValue = false
                    }
                )
                return unsafeBitCast(ctx, to: Content.Context.self)
            }
            let ctx = _openExistential(adapter.context!, do: project)
            if adapter.viewController == nil {
                adapter.viewController = destination.makeUIViewController(context: ctx)
            } else {
                let viewController = adapter.viewController as! Content.UIViewControllerType
                destination.updateUIViewController(viewController, context: ctx)
            }
        }
    }
}

@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension PresentationLinkTransition.Value {

    func update<Content: View>(_ viewController: HostingController<Content>) {

        viewController.modalPresentationCapturesStatusBarAppearance = options.modalPresentationCapturesStatusBarAppearance
        viewController.view.backgroundColor = options.preferredPresentationBackgroundUIColor ?? .systemBackground

        switch self {
        case .sheet(let options):
            if #available(iOS 15.0, *) {
                viewController.tracksContentSize = options.widthFollowsPreferredContentSizeWhenEdgeAttached || options.detents.contains(where: { $0.identifier == .ideal })
            } else {
                viewController.tracksContentSize = options.widthFollowsPreferredContentSizeWhenEdgeAttached
            }

        case .popover:
            viewController.tracksContentSize = true

        default:
            break
        }
    }
}

#endif