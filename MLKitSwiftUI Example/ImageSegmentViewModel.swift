//
//  ImageSegmentViewModel.swift
//  MLKitSwiftUI Example
//
//  Created by Dohyun Ji on 2021/04/11.
//

import SwiftUI
import MLKit


class ImageSegmentViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var segmentedImage: UIImage?
    @Published var isPresentingImagePicker: Bool = false
    @Published var isProcessing: Bool = false
    private(set) var sourceType: ImagePicker.SourceType = .camera
    private let selfieSegmentation = SelfieSegmentation()
    
    func choosePhoto() {
        sourceType = .photoLibrary
        isPresentingImagePicker = true
    }
    
    func didSelectImage(_ image: UIImage?) {
        guard let image = image else { return }
        selectedImage = nil
        isProcessing = true
        selectedImage = image
        selfieSegmentation.getSegmentedImage(image: image) { (result) -> () in
            self.segmentedImage = result
            self.isProcessing = false
        }
        isPresentingImagePicker = false
    }
}

struct SelfieSegmentation {
    let segmenter: Segmenter
    
    init() {
        let options = SelfieSegmenterOptions()
        options.segmenterMode = .singleImage
        segmenter = Segmenter.segmenter(options: options)
    }
    
    func getSegmentedImage(image: UIImage, onReady: @escaping (UIImage?) -> ()) {
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        
        segmenter.process(visionImage) { mask, error in
            guard error == nil, let mask = mask else { return }
            onReady(ImageUtils.applyMask(mask: mask, image: image))
        }
    }
}
