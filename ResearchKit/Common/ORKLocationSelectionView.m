/*
 Copyright (c) 2015, Alejandro Martinez, Quintiles Inc.
 Copyright (c) 2015, Brian Kelly, Quintiles Inc.
 Copyright (c) 2015, Bryan Strothmann, Quintiles Inc.
 Copyright (c) 2015, Greg Yip, Quintiles Inc.
 Copyright (c) 2015, John Reites, Quintiles Inc.
 Copyright (c) 2015, Pavel Kanzelsberger, Quintiles Inc.
 Copyright (c) 2015, Richard Thomas, Quintiles Inc.
 Copyright (c) 2015, Shelby Brooks, Quintiles Inc.
 Copyright (c) 2015, Steve Cadwallader, Quintiles Inc.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ORKLocationSelectionView.h"
#import <MapKit/MapKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "ORKAnswerTextField.h"
#import "ORKHelpers.h"
#import "ORKAnswerFormat_Internal.h"
#import "ORKPlacemark.h"
#import "ORKSkin.h"


@interface ORKLocationSelectionView () <UITextFieldDelegate, MKMapViewDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) NSLayoutConstraint *mapViewHeightConstraint;
@property (nonatomic, strong) ORKAnswerTextField *textField;
@property (nonatomic, strong) MKMapView *mapView;
@end


@implementation ORKLocationSelectionView {
    CLLocationManager *_locationManager;
    BOOL _userLocationNeedsUpdate;
    MKCoordinateRegion _answerRegion;
    MKCoordinateRegion _initalCoordinateRegion;
    BOOL _setInitialCoordinateRegion;
    BOOL _edgeToEdgeMap;
}

- (instancetype)initWithOpenMap:(BOOL)openMap useCurrentLocation:(BOOL)use edgeToEdgePresentation:(BOOL)edgeToEdgePresentation {
    
    if (openMap) {
        self = [super initWithFrame:CGRectMake(0.0, 0.0, 200.0, LocationSelectionViewTextFieldHeight + (2 * LocationSelectionViewTextFieldVerticalMargin) + ORKGetMetricForWindow(ORKScreenMetricLocationQuestionMapHeight, self.window))];
    } else {
        self = [super initWithFrame:CGRectMake(0.0, 0.0, 200.0, LocationSelectionViewTextFieldHeight + (2 * LocationSelectionViewTextFieldVerticalMargin))];
    }
    
    if (self) {
        _textField = [[ORKAnswerTextField alloc] init];
        _textField.delegate = self;
        _textField.placeholder = ORKLocalizedString(@"LOCATION_ADDRESS",nil);
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.returnKeyType = UIReturnKeySearch;
        _textField.adjustsFontSizeToFitWidth = YES;
        
        _useCurrentLocation = use;
        _edgeToEdgeMap = edgeToEdgePresentation;
        
        [self addSubview:_textField];
        [self setUpConstraints];

        if (openMap) {
            [self showMapView];
        }
    }
    
    return self;
}

- (void)setUpConstraints {
    NSMutableArray *constraints = [NSMutableArray new];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_textField);
    ORKEnableAutoLayoutForViews([views allValues]);
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:LocationSelectionViewTextFieldVerticalMargin]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:LocationSelectionViewTextFieldHeight]];
    
    NSDictionary *metrics = @{@"horizontalMargin": (_edgeToEdgeMap ? @(20.0) : @(0.0))};
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(horizontalMargin)-[_textField]-(horizontalMargin)-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:metrics views:views]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)setPlaceholderText:(NSString *)text {
    _textField.placeholder = text;
}

- (void)setTextColor:(UIColor *)color {
    _textField.textColor = color;
}

- (NSString *)enteredLocation {
    return [_textField.text copy];
}

- (BOOL)becomeFirstResponder {
    return [_textField becomeFirstResponder];
}

- (BOOL)isFirstResponder {
    return [_textField isFirstResponder];
}

- (BOOL)resignFirstResponder {
    return [_textField resignFirstResponder];
}

- (CGSize)intrinsicContentSize {
    CGFloat height = LocationSelectionViewTextFieldHeight + (2 * LocationSelectionViewTextFieldVerticalMargin) + (_mapView == nil ? 0.0 : ORKGetMetricForWindow(ORKScreenMetricLocationQuestionMapHeight, self.window));
    return CGSizeMake(40, height);
}

- (void)showMapView {
    if (_mapView) {
        return;
    }
    
    _mapView = [[MKMapView alloc] init];
    _mapView.delegate = self;
    _mapView.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, 0.0);
    ORKEnableAutoLayoutForViews(@[_mapView]);
    
    if (!_edgeToEdgeMap) {
        _mapView.layer.cornerRadius = 3;
        _mapView.layer.borderColor = [UIColor colorWithRed:(204.0/255.0) green:(204.0/255.0) blue:(204.0/255.0) alpha:.75].CGColor;
        _mapView.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    }
    [self addSubview:_mapView];
    
    [self loadCurrentLocationIfNecessary];
    
    if (_answer) {
        [self setAnswer:_answer];
    }
    
    NSMutableArray *constraints = [NSMutableArray new];
    
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_mapView]|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_mapView)]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_mapView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-LocationSelectionViewTextFieldVerticalMargin]];
    _mapViewHeightConstraint = [NSLayoutConstraint constraintWithItem:_mapView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:ORKGetMetricForWindow(ORKScreenMetricLocationQuestionMapHeight, self.window)];
    [constraints addObject:_mapViewHeightConstraint];
    
    [NSLayoutConstraint activateConstraints:constraints];
    [self layoutIfNeeded];
    if ([_delegate respondsToSelector:@selector(locationSelectionViewNeedsResize:)]) {
        [_delegate locationSelectionViewNeedsResize:self];
    }
}

- (void)loadCurrentLocationIfNecessary {
    if (_useCurrentLocation) {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        
        if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
            _userLocationNeedsUpdate = YES;
            _mapView.showsUserLocation = YES;
        } else {
            _locationManager = [[CLLocationManager alloc] init];
            _locationManager.delegate = self;
            [_locationManager requestWhenInUseAuthorization];
        }
    }
}

- (void)geocodeAndDisplay:(NSString *)string {
    
    if (string == nil || string.length == 0) {
        [self setAnswer:ORKNullAnswerValue()];
        return;
    }
    
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    __weak __typeof__(self) weakSelf = self;
    [geocoder geocodeAddressString:string completionHandler:^(NSArray *placemarks, NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (error) {
            if ([_delegate respondsToSelector:@selector(locationSelectionView:didFailWithError:)]) {
                [_delegate locationSelectionView:self didFailWithError:error];
            }
            [strongSelf setAnswer:ORKNullAnswerValue()];
        } else {
            CLPlacemark *placemark = [placemarks lastObject];
            [strongSelf setAnswer:placemark];
        }
    }];
}

- (void)reverseGeocodeAndDisplay:(CLLocation *)location {
    
    if (location == nil) {
        [self setAnswer:ORKNullAnswerValue()];
        return;
    }
    
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    __weak __typeof__(self) weakSelf = self;
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (error) {
            if ([_delegate respondsToSelector:@selector(locationSelectionView:didFailWithError:)]) {
                [_delegate locationSelectionView:self didFailWithError:error];
            }
            [strongSelf setAnswer:ORKNullAnswerValue()];
        } else {
            CLPlacemark *placemark = [placemarks lastObject];
            [strongSelf setAnswer:placemark];
        }
    }];
}

- (void)setAnswer:(id)answer {
    
    [_mapView removeAnnotations:_mapView.annotations];
    
    if ([[answer class] isSubclassOfClass:[CLPlacemark class]]) {
        _answer = [[ORKPlacemark alloc] initWithPlacemark:answer];
    } else {
        _answer = answer == ORKNullAnswerValue() ? ORKNullAnswerValue() : nil;
    }
    
    if (_answer) {
        _userLocationNeedsUpdate = NO;
    }
    
    if ([[_answer class] isSubclassOfClass:[CLPlacemark class]]) {
        ORKPlacemark *placemarkAnswer = [[ORKPlacemark alloc] initWithPlacemark:(CLPlacemark *)answer];
        [_mapView addAnnotation:placemarkAnswer];
        
        float spanX = 0.00725;
        float spanY = 0.00725;
        MKCoordinateRegion region;
        region.center = placemarkAnswer.location.coordinate;
        region.span = MKCoordinateSpanMake(spanX, spanY);
        _answerRegion = region;
        if (!_setInitialCoordinateRegion) {
            _setInitialCoordinateRegion = YES;
            _initalCoordinateRegion = _mapView.region;
        }
        [_mapView setRegion:region animated:YES];
        
        if (placemarkAnswer.addressDictionary) {
            _textField.text = ABCreateStringWithAddressDictionary(placemarkAnswer.addressDictionary, NO);
        } else {
            CLLocationCoordinate2D coordinate = placemarkAnswer.location.coordinate;
            CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
            [self reverseGeocodeAndDisplay:location];
        }
    } else {
        if (_setInitialCoordinateRegion) {
            [_mapView setRegion:_initalCoordinateRegion animated:YES];
        }
    }
    
    if ([_delegate respondsToSelector:@selector(locationSelectionViewDidChange:)]) {
        [_delegate locationSelectionViewDidChange:self];
    }
}

# pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self loadCurrentLocationIfNecessary];
    }
}

#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (_userLocationNeedsUpdate) {
        _textField.text = @"";
        MKCoordinateRegion reigon = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 1000, 1000);
        [_mapView setRegion:reigon animated:YES];
        [self reverseGeocodeAndDisplay:userLocation.location];
        _userLocationNeedsUpdate = NO;
    }
}

#pragma mark UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if ([_delegate respondsToSelector:@selector(locationSelectionViewDidBeginEditing:)]) {
        [_delegate locationSelectionViewDidBeginEditing:self];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [textField resignFirstResponder];
    [self geocodeAndDisplay:textField.text];
    if ([_delegate respondsToSelector:@selector(locationSelectionViewDidEndEditing:)]) {
        [_delegate locationSelectionViewDidEndEditing:self];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self geocodeAndDisplay:textField.text];
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    [_mapView setRegion:_initalCoordinateRegion animated:YES];
    [self setAnswer:ORKNullAnswerValue()];
    return YES;
}

@end
