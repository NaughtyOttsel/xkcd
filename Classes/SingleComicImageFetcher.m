//
//  SingleComicImageFetcher.m
//  xkcd
//
//  Created by Joshua Bleecher Snyder on 9/2/09.
//  Copyright 2009 Treeline Labs. All rights reserved.
//

#import "SingleComicImageFetcher.h"
#import "FetchComicImageFromWeb.h"
#import "Comic.h"
#import "XkcdErrorCodes.h"

#pragma mark -

@interface SingleComicImageFetcher ()

- (void)didCompleteFetchOperation:(FetchComicImageFromWeb *)fetchOperation;
- (void)enqueueMoreDownloadAllComics;
- (void)didFailWithError:(NSError *)error onComic:(Comic *)comic;

@property (nonatomic) id keepInMemory;
@property (nonatomic) NSOperationQueue *fetchQueue;
@property (nonatomic) NSMutableArray *comicsRemainingDuringDownloadAll;
@property (nonatomic) NSURLSession *URLSession;

@end

#pragma mark -

@implementation SingleComicImageFetcher

- (instancetype)initWithURLSession:(NSURLSession *)session {
  if (self = [super init]) {
      _fetchQueue = [[NSOperationQueue alloc] init];
      _URLSession = session;
  }
  return self;
}

- (void)fetchImageForComic:(Comic *)comic context:(id)context {
  if (comic.imageURL) {
    NSURL *comicImageURL = [NSURL URLWithString:comic.imageURL];
    FetchComicImageFromWeb *fetchOperation = [[FetchComicImageFromWeb alloc] initWithComicNumber:[comic.number integerValue]
                                                                                         imageURL:comicImageURL
                                                                                      URLSession:self.URLSession
                                                                                 completionTarget:self
                                                                                           action:@selector(didCompleteFetchOperation:)
                                                                                          context:context];
    comic.loading = @YES;
    self.keepInMemory = self;
    [self.fetchQueue addOperation:fetchOperation];
  } else {
	  [self didFailWithError:[NSError errorWithDomain:kXkcdErrorDomain
												 code:kXkcdErrorCodeBlankImageURL
											 userInfo:nil]
					 onComic:comic];
  }
}

- (void)fetchImagesForAllComics {
	// don't start afresh if there's a download-all ongoing!
	if (!self.comicsRemainingDuringDownloadAll) {
		self.comicsRemainingDuringDownloadAll = [[Comic comicsWithoutImages] mutableCopy];
		[self enqueueMoreDownloadAllComics];
	}
}

- (void)enqueueMoreDownloadAllComics {
	NSUInteger comicsRemainingCount = [self.comicsRemainingDuringDownloadAll count];
	if (comicsRemainingCount == 0) {
		// done!
		self.comicsRemainingDuringDownloadAll = nil;
	} else {
		// not done...start another
		Comic *comic = [self.comicsRemainingDuringDownloadAll lastObject];
		[self fetchImageForComic:comic context:@NO]; // open after download: NO
		[self.comicsRemainingDuringDownloadAll removeLastObject];
	}
}

- (BOOL)downloadingAll {
	return (self.comicsRemainingDuringDownloadAll != nil);
}

- (void)cancelDownloadAll {
	self.comicsRemainingDuringDownloadAll = nil;
	self.keepInMemory = nil;
}

- (void)didCompleteFetchOperation:(FetchComicImageFromWeb *)fetchOperation {
	Comic *comic = [Comic comicNumbered:fetchOperation.comicNumber];
	comic.loading = @NO;
	if (!fetchOperation.error && fetchOperation.comicImageData) {
		[comic saveImageData:fetchOperation.comicImageData];
		[self.delegate singleComicImageFetcher:self
						 didFetchImageForComic:comic
									   context:fetchOperation.context];
	} else {
		[self didFailWithError:fetchOperation.error onComic:comic];
	}
	
	if (self.comicsRemainingDuringDownloadAll) {
		[self enqueueMoreDownloadAllComics];
	}
	
	self.keepInMemory = nil;
}

- (void)didFailWithError:(NSError *)error onComic:(Comic *)comic {
	// Tell the delegate
	[self.delegate singleComicImageFetcher:self
						  didFailWithError:error
								   onComic:comic];
}

- (void)dealloc {
  [self.fetchQueue cancelAllOperations];
  self.keepInMemory = nil;
}

@end
