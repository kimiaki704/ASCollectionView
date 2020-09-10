//
//  StickyHeader.swift
//  ASCollectionView
//
//  Created by 坂上 翔悟 on 2020/09/10.
//

import UIKit
import SwiftUI

@available(iOS 13.0, *)
struct StickyHeaderSetting {
    var height: CGFloat = 0.0
    var minimumHeight: CGFloat = 0.0
    var mode: StickyHeaderMode = .fill
    var content: () -> AnyView
    @Binding var progress: CGFloat
}

public enum StickyHeaderMode: Int {
    case fill
    case topFill
    case top
    case center
    case bottom
    case bottomFill
}

public protocol StickyHeaderDelegate: NSObjectProtocol {
    /// Headerがスクロールしたことを通知する
    ///
    /// - Parameter stickyHeader: スクロールするHeader
    func stickyHeaderDidScroll(_ stickyHeader: StickyHeader)
}

extension StickyHeaderDelegate {
    func stickyHeaderDidScroll(_ stickyHeader: StickyHeader) {}
}

open class StickyHeader: NSObject {
    /// UIScrollViewのコンテンツ上にあるコンテンツビュー
    open private(set) var contentView: UIView = UIView() {
        didSet {
            contentView.clipsToBounds = true
        }
    }

    open weak var delegate: StickyHeaderDelegate?

    private var scrollViewObservation: NSKeyValueObservation?
    weak var scrollView: UIScrollView! {
        didSet {
            guard let scrollView = scrollView, scrollView != oldValue else { return }
            adjustScrollViewTopInset(top: scrollView.contentInset.top + height)
            scrollView.addSubview(contentView)
            layoutContentView()

            // contentOffsetの更新を監視する
            scrollViewObservation = scrollView.observe(\.contentOffset) { [weak self] _, _ in
                self?.layoutContentView()
            }
        }
    }

    /// ヘッダービュー
    open var view: UIView? {
        didSet {
            if view != oldValue {
                oldValue?.removeFromSuperview()
                updateConstraints()
            }
        }
    }

    /// ヘッダー縦幅
    open var height: CGFloat = 0.0 {
        didSet {
            if let scrollView = scrollView, height != oldValue {
                adjustScrollViewTopInset(top: scrollView.contentInset.top - oldValue + height)
                updateConstraints()
                layoutContentView()
            }
        }
    }

    open var minimumHeight: CGFloat = 0.0 {
        didSet {
            layoutContentView()
        }
    }

    open var mode: StickyHeaderMode = .fill {
        didSet {
            if mode != oldValue {
                updateConstraints()
            }
        }
    }

    open var progress: CGFloat = 0 {
        didSet {
            if progress != oldValue {
                self.delegate?.stickyHeaderDidScroll(self)
            }
        }
    }

    open func load(
        withNibName name: String,
        bundle bundleOrNil: Bundle?,
        options optionsOrNil: [UINib.OptionsKey: Any]? = nil
    ) {
        let nib = UINib(nibName: name, bundle: bundleOrNil)
        nib.instantiate(withOwner: self, options: optionsOrNil)
    }

    private func updateConstraints() {
        guard let view = view else { return }

        view.removeFromSuperview()
        contentView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        switch mode {
        case .fill:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        case .topFill:
            let bottomAnchor = view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            bottomAnchor.priority = .defaultHigh
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.heightAnchor.constraint(equalToConstant: height),
                bottomAnchor
            ])
        case .top:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.heightAnchor.constraint(equalToConstant: height)
            ])
        case .bottom:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                view.heightAnchor.constraint(equalToConstant: height)
            ])
        case .bottomFill:
            let topAnchor = view.topAnchor.constraint(equalTo: contentView.topAnchor)
            topAnchor.priority = .defaultHigh
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                view.heightAnchor.constraint(greaterThanOrEqualToConstant: height),
                topAnchor
            ])
        case .center:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                view.heightAnchor.constraint(equalToConstant: height)
            ])
        }
    }

    private func layoutContentView() {
        let mostMinimumHeight = min(minimumHeight, height)
        let relativeYOffset = scrollView.contentOffset.y + scrollView.contentInset.top - height
        let relativeHeight = -relativeYOffset
        let frame = CGRect(
            x: 0,
            y: relativeYOffset,
            width: scrollView.frame.size.width,
            height: max(relativeHeight, mostMinimumHeight)
        )

        contentView.frame = frame
        let div = height - minimumHeight
        progress = (contentView.frame.size.height - minimumHeight) / div
    }

    private func adjustScrollViewTopInset(top: CGFloat) {
        var inset = scrollView.contentInset
        var offset = scrollView.contentOffset

        offset.y += inset.top - top
        scrollView.contentOffset = offset

        inset.top = top
        scrollView.contentInset = inset
    }
}

private var stickyHeaderContext: UInt8 = 0

extension UIScrollView {
    /// UIScrollViewへstickyHeaderプロパティを追加
    open var stickyHeader: StickyHeader! {
        // scrollViewからStickyHeaderを取得
        var header = objc_getAssociatedObject(self, &stickyHeaderContext) as? StickyHeader
        // 取得できなかったらStickyHeaderを追加する
        if header == nil {
            header = StickyHeader()
            header!.scrollView = self
            objc_setAssociatedObject(
                self,
                &stickyHeaderContext,
                header,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        return header
    }
}
