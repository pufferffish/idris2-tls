module Crypto.AES

import Data.Bits
import Data.DPair
import Data.Fin
import Data.List
import Data.Nat
import Data.Stream
import Data.Vect
import Utils.Misc
import Utils.Bytes

matmul : Num a => {p : _} -> (op : Vect m a -> Vect m b -> c) -> Vect n (Vect m a) -> Vect m (Vect p b) -> Vect n (Vect p c)
matmul op [] ys = []
matmul op (x :: xs) ys = map (op x) (transpose ys) :: matmul op xs ys

vecxor : Bits a => Vect n a -> Vect n a -> Vect n a
vecxor = zipWith xor

matxor : Bits a => Vect n (Vect m a) -> Vect n (Vect m a) -> Vect n (Vect m a)
matxor x y = zipWith vecxor x y

sbox : Vect 256 Bits8
sbox =
  [ 0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76
  , 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0
  , 0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15
  , 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75
  , 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84
  , 0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf
  , 0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8
  , 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2
  , 0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73
  , 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb
  , 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79
  , 0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08
  , 0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a
  , 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e
  , 0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf
  , 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ]

inv_sbox : Vect 256 Bits8
inv_sbox =
  [ 0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb
  , 0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb
  , 0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e
  , 0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25
  , 0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92
  , 0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84
  , 0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06
  , 0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b
  , 0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73
  , 0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e
  , 0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b
  , 0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4
  , 0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f
  , 0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef
  , 0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61
  , 0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
  ]

gbox_9 : Vect 256 Bits8
gbox_9 =
  [ 0x00, 0x09, 0x12, 0x1b, 0x24, 0x2d, 0x36, 0x3f, 0x48, 0x41, 0x5a, 0x53, 0x6c, 0x65, 0x7e, 0x77
  , 0x90, 0x99, 0x82, 0x8b, 0xb4, 0xbd, 0xa6, 0xaf, 0xd8, 0xd1, 0xca, 0xc3, 0xfc, 0xf5, 0xee, 0xe7
  , 0x3b, 0x32, 0x29, 0x20, 0x1f, 0x16, 0x0d, 0x04, 0x73, 0x7a, 0x61, 0x68, 0x57, 0x5e, 0x45, 0x4c
  , 0xab, 0xa2, 0xb9, 0xb0, 0x8f, 0x86, 0x9d, 0x94, 0xe3, 0xea, 0xf1, 0xf8, 0xc7, 0xce, 0xd5, 0xdc
  , 0x76, 0x7f, 0x64, 0x6d, 0x52, 0x5b, 0x40, 0x49, 0x3e, 0x37, 0x2c, 0x25, 0x1a, 0x13, 0x08, 0x01
  , 0xe6, 0xef, 0xf4, 0xfd, 0xc2, 0xcb, 0xd0, 0xd9, 0xae, 0xa7, 0xbc, 0xb5, 0x8a, 0x83, 0x98, 0x91
  , 0x4d, 0x44, 0x5f, 0x56, 0x69, 0x60, 0x7b, 0x72, 0x05, 0x0c, 0x17, 0x1e, 0x21, 0x28, 0x33, 0x3a
  , 0xdd, 0xd4, 0xcf, 0xc6, 0xf9, 0xf0, 0xeb, 0xe2, 0x95, 0x9c, 0x87, 0x8e, 0xb1, 0xb8, 0xa3, 0xaa
  , 0xec, 0xe5, 0xfe, 0xf7, 0xc8, 0xc1, 0xda, 0xd3, 0xa4, 0xad, 0xb6, 0xbf, 0x80, 0x89, 0x92, 0x9b
  , 0x7c, 0x75, 0x6e, 0x67, 0x58, 0x51, 0x4a, 0x43, 0x34, 0x3d, 0x26, 0x2f, 0x10, 0x19, 0x02, 0x0b
  , 0xd7, 0xde, 0xc5, 0xcc, 0xf3, 0xfa, 0xe1, 0xe8, 0x9f, 0x96, 0x8d, 0x84, 0xbb, 0xb2, 0xa9, 0xa0
  , 0x47, 0x4e, 0x55, 0x5c, 0x63, 0x6a, 0x71, 0x78, 0x0f, 0x06, 0x1d, 0x14, 0x2b, 0x22, 0x39, 0x30
  , 0x9a, 0x93, 0x88, 0x81, 0xbe, 0xb7, 0xac, 0xa5, 0xd2, 0xdb, 0xc0, 0xc9, 0xf6, 0xff, 0xe4, 0xed
  , 0x0a, 0x03, 0x18, 0x11, 0x2e, 0x27, 0x3c, 0x35, 0x42, 0x4b, 0x50, 0x59, 0x66, 0x6f, 0x74, 0x7d
  , 0xa1, 0xa8, 0xb3, 0xba, 0x85, 0x8c, 0x97, 0x9e, 0xe9, 0xe0, 0xfb, 0xf2, 0xcd, 0xc4, 0xdf, 0xd6
  , 0x31, 0x38, 0x23, 0x2a, 0x15, 0x1c, 0x07, 0x0e, 0x79, 0x70, 0x6b, 0x62, 0x5d, 0x54, 0x4f, 0x46
  ]

gbox_11 : Vect 256 Bits8
gbox_11 =
  [ 0x00, 0x0b, 0x16, 0x1d, 0x2c, 0x27, 0x3a, 0x31, 0x58, 0x53, 0x4e, 0x45, 0x74, 0x7f, 0x62, 0x69
  , 0xb0, 0xbb, 0xa6, 0xad, 0x9c, 0x97, 0x8a, 0x81, 0xe8, 0xe3, 0xfe, 0xf5, 0xc4, 0xcf, 0xd2, 0xd9
  , 0x7b, 0x70, 0x6d, 0x66, 0x57, 0x5c, 0x41, 0x4a, 0x23, 0x28, 0x35, 0x3e, 0x0f, 0x04, 0x19, 0x12
  , 0xcb, 0xc0, 0xdd, 0xd6, 0xe7, 0xec, 0xf1, 0xfa, 0x93, 0x98, 0x85, 0x8e, 0xbf, 0xb4, 0xa9, 0xa2
  , 0xf6, 0xfd, 0xe0, 0xeb, 0xda, 0xd1, 0xcc, 0xc7, 0xae, 0xa5, 0xb8, 0xb3, 0x82, 0x89, 0x94, 0x9f
  , 0x46, 0x4d, 0x50, 0x5b, 0x6a, 0x61, 0x7c, 0x77, 0x1e, 0x15, 0x08, 0x03, 0x32, 0x39, 0x24, 0x2f
  , 0x8d, 0x86, 0x9b, 0x90, 0xa1, 0xaa, 0xb7, 0xbc, 0xd5, 0xde, 0xc3, 0xc8, 0xf9, 0xf2, 0xef, 0xe4
  , 0x3d, 0x36, 0x2b, 0x20, 0x11, 0x1a, 0x07, 0x0c, 0x65, 0x6e, 0x73, 0x78, 0x49, 0x42, 0x5f, 0x54
  , 0xf7, 0xfc, 0xe1, 0xea, 0xdb, 0xd0, 0xcd, 0xc6, 0xaf, 0xa4, 0xb9, 0xb2, 0x83, 0x88, 0x95, 0x9e
  , 0x47, 0x4c, 0x51, 0x5a, 0x6b, 0x60, 0x7d, 0x76, 0x1f, 0x14, 0x09, 0x02, 0x33, 0x38, 0x25, 0x2e
  , 0x8c, 0x87, 0x9a, 0x91, 0xa0, 0xab, 0xb6, 0xbd, 0xd4, 0xdf, 0xc2, 0xc9, 0xf8, 0xf3, 0xee, 0xe5
  , 0x3c, 0x37, 0x2a, 0x21, 0x10, 0x1b, 0x06, 0x0d, 0x64, 0x6f, 0x72, 0x79, 0x48, 0x43, 0x5e, 0x55
  , 0x01, 0x0a, 0x17, 0x1c, 0x2d, 0x26, 0x3b, 0x30, 0x59, 0x52, 0x4f, 0x44, 0x75, 0x7e, 0x63, 0x68
  , 0xb1, 0xba, 0xa7, 0xac, 0x9d, 0x96, 0x8b, 0x80, 0xe9, 0xe2, 0xff, 0xf4, 0xc5, 0xce, 0xd3, 0xd8
  , 0x7a, 0x71, 0x6c, 0x67, 0x56, 0x5d, 0x40, 0x4b, 0x22, 0x29, 0x34, 0x3f, 0x0e, 0x05, 0x18, 0x13
  , 0xca, 0xc1, 0xdc, 0xd7, 0xe6, 0xed, 0xf0, 0xfb, 0x92, 0x99, 0x84, 0x8f, 0xbe, 0xb5, 0xa8, 0xa3
  ]

gbox_13 : Vect 256 Bits8
gbox_13 =
  [ 0x00, 0x0d, 0x1a, 0x17, 0x34, 0x39, 0x2e, 0x23, 0x68, 0x65, 0x72, 0x7f, 0x5c, 0x51, 0x46, 0x4b
  , 0xd0, 0xdd, 0xca, 0xc7, 0xe4, 0xe9, 0xfe, 0xf3, 0xb8, 0xb5, 0xa2, 0xaf, 0x8c, 0x81, 0x96, 0x9b
  , 0xbb, 0xb6, 0xa1, 0xac, 0x8f, 0x82, 0x95, 0x98, 0xd3, 0xde, 0xc9, 0xc4, 0xe7, 0xea, 0xfd, 0xf0
  , 0x6b, 0x66, 0x71, 0x7c, 0x5f, 0x52, 0x45, 0x48, 0x03, 0x0e, 0x19, 0x14, 0x37, 0x3a, 0x2d, 0x20
  , 0x6d, 0x60, 0x77, 0x7a, 0x59, 0x54, 0x43, 0x4e, 0x05, 0x08, 0x1f, 0x12, 0x31, 0x3c, 0x2b, 0x26
  , 0xbd, 0xb0, 0xa7, 0xaa, 0x89, 0x84, 0x93, 0x9e, 0xd5, 0xd8, 0xcf, 0xc2, 0xe1, 0xec, 0xfb, 0xf6
  , 0xd6, 0xdb, 0xcc, 0xc1, 0xe2, 0xef, 0xf8, 0xf5, 0xbe, 0xb3, 0xa4, 0xa9, 0x8a, 0x87, 0x90, 0x9d
  , 0x06, 0x0b, 0x1c, 0x11, 0x32, 0x3f, 0x28, 0x25, 0x6e, 0x63, 0x74, 0x79, 0x5a, 0x57, 0x40, 0x4d
  , 0xda, 0xd7, 0xc0, 0xcd, 0xee, 0xe3, 0xf4, 0xf9, 0xb2, 0xbf, 0xa8, 0xa5, 0x86, 0x8b, 0x9c, 0x91
  , 0x0a, 0x07, 0x10, 0x1d, 0x3e, 0x33, 0x24, 0x29, 0x62, 0x6f, 0x78, 0x75, 0x56, 0x5b, 0x4c, 0x41
  , 0x61, 0x6c, 0x7b, 0x76, 0x55, 0x58, 0x4f, 0x42, 0x09, 0x04, 0x13, 0x1e, 0x3d, 0x30, 0x27, 0x2a
  , 0xb1, 0xbc, 0xab, 0xa6, 0x85, 0x88, 0x9f, 0x92, 0xd9, 0xd4, 0xc3, 0xce, 0xed, 0xe0, 0xf7, 0xfa
  , 0xb7, 0xba, 0xad, 0xa0, 0x83, 0x8e, 0x99, 0x94, 0xdf, 0xd2, 0xc5, 0xc8, 0xeb, 0xe6, 0xf1, 0xfc
  , 0x67, 0x6a, 0x7d, 0x70, 0x53, 0x5e, 0x49, 0x44, 0x0f, 0x02, 0x15, 0x18, 0x3b, 0x36, 0x21, 0x2c
  , 0x0c, 0x01, 0x16, 0x1b, 0x38, 0x35, 0x22, 0x2f, 0x64, 0x69, 0x7e, 0x73, 0x50, 0x5d, 0x4a, 0x47
  , 0xdc, 0xd1, 0xc6, 0xcb, 0xe8, 0xe5, 0xf2, 0xff, 0xb4, 0xb9, 0xae, 0xa3, 0x80, 0x8d, 0x9a, 0x97
  ]

gbox_14 : Vect 256 Bits8
gbox_14 =
  [ 0x00, 0x0e, 0x1c, 0x12, 0x38, 0x36, 0x24, 0x2a, 0x70, 0x7e, 0x6c, 0x62, 0x48, 0x46, 0x54, 0x5a
  , 0xe0, 0xee, 0xfc, 0xf2, 0xd8, 0xd6, 0xc4, 0xca, 0x90, 0x9e, 0x8c, 0x82, 0xa8, 0xa6, 0xb4, 0xba
  , 0xdb, 0xd5, 0xc7, 0xc9, 0xe3, 0xed, 0xff, 0xf1, 0xab, 0xa5, 0xb7, 0xb9, 0x93, 0x9d, 0x8f, 0x81
  , 0x3b, 0x35, 0x27, 0x29, 0x03, 0x0d, 0x1f, 0x11, 0x4b, 0x45, 0x57, 0x59, 0x73, 0x7d, 0x6f, 0x61
  , 0xad, 0xa3, 0xb1, 0xbf, 0x95, 0x9b, 0x89, 0x87, 0xdd, 0xd3, 0xc1, 0xcf, 0xe5, 0xeb, 0xf9, 0xf7
  , 0x4d, 0x43, 0x51, 0x5f, 0x75, 0x7b, 0x69, 0x67, 0x3d, 0x33, 0x21, 0x2f, 0x05, 0x0b, 0x19, 0x17
  , 0x76, 0x78, 0x6a, 0x64, 0x4e, 0x40, 0x52, 0x5c, 0x06, 0x08, 0x1a, 0x14, 0x3e, 0x30, 0x22, 0x2c
  , 0x96, 0x98, 0x8a, 0x84, 0xae, 0xa0, 0xb2, 0xbc, 0xe6, 0xe8, 0xfa, 0xf4, 0xde, 0xd0, 0xc2, 0xcc
  , 0x41, 0x4f, 0x5d, 0x53, 0x79, 0x77, 0x65, 0x6b, 0x31, 0x3f, 0x2d, 0x23, 0x09, 0x07, 0x15, 0x1b
  , 0xa1, 0xaf, 0xbd, 0xb3, 0x99, 0x97, 0x85, 0x8b, 0xd1, 0xdf, 0xcd, 0xc3, 0xe9, 0xe7, 0xf5, 0xfb
  , 0x9a, 0x94, 0x86, 0x88, 0xa2, 0xac, 0xbe, 0xb0, 0xea, 0xe4, 0xf6, 0xf8, 0xd2, 0xdc, 0xce, 0xc0
  , 0x7a, 0x74, 0x66, 0x68, 0x42, 0x4c, 0x5e, 0x50, 0x0a, 0x04, 0x16, 0x18, 0x32, 0x3c, 0x2e, 0x20
  , 0xec, 0xe2, 0xf0, 0xfe, 0xd4, 0xda, 0xc8, 0xc6, 0x9c, 0x92, 0x80, 0x8e, 0xa4, 0xaa, 0xb8, 0xb6
  , 0x0c, 0x02, 0x10, 0x1e, 0x34, 0x3a, 0x28, 0x26, 0x7c, 0x72, 0x60, 0x6e, 0x44, 0x4a, 0x58, 0x56
  , 0x37, 0x39, 0x2b, 0x25, 0x0f, 0x01, 0x13, 0x1d, 0x47, 0x49, 0x5b, 0x55, 0x7f, 0x71, 0x63, 0x6d
  , 0xd7, 0xd9, 0xcb, 0xc5, 0xef, 0xe1, 0xf3, 0xfd, 0xa7, 0xa9, 0xbb, 0xb5, 0x9f, 0x91, 0x83, 0x8d
  ]

data G : Type where
  G1 : G
  G2 : G
  G3 : G

data G' : Type where
  G9 : G'
  G11 : G'
  G13 : G'
  G14 : G'

mix_columns_mat : Vect 4 (Vect 4 G)
mix_columns_mat = [[G2, G1, G1, G3], [G3, G2, G1, G1], [G1, G3, G2, G1], [G1, G1, G3, G2]]

inv_mix_columns_mat : Vect 4 (Vect 4 G')
inv_mix_columns_mat = [[G14, G9, G13, G11], [G11, G14, G9, G13], [G13, G11, G14, G9], [G9, G13, G11, G14]]

||| RotWord
rot_word : {n : Nat} -> Nat -> Vect (S n) a -> Vect (S n) a
rot_word k = take (S n) . drop k . cycle

||| InvRotWord
inv_rot_word : {n : Nat} -> Nat -> Vect (S n) a -> Vect (S n) a
inv_rot_word k = take (S n) . drop (n * k) . cycle

sub_byte : Bits8 -> Bits8
sub_byte x = index (b8_to_fin x) sbox

inv_sub_byte : Bits8 -> Bits8
inv_sub_byte x = index (b8_to_fin x) inv_sbox

||| SubWord
sub_word : Vect m Bits8 -> Vect m Bits8
sub_word = map sub_byte

||| InvSubWord
inv_sub_word : Vect m Bits8 -> Vect m Bits8
inv_sub_word = map inv_sub_byte

||| SubBytes
sub_bytes : Vect n (Vect m Bits8) -> Vect n (Vect m Bits8)
sub_bytes = map sub_word

||| InvSubBytes
inv_sub_bytes : Vect n (Vect m Bits8) -> Vect n (Vect m Bits8)
inv_sub_bytes = map inv_sub_word

shift_rows' : {m : _} -> Nat -> Vect n (Vect (S m) Bits8) -> Vect n (Vect (S m) Bits8)
shift_rows' n [] = []
shift_rows' n (x :: xs) = rot_word n x :: shift_rows' (S n) xs

||| ShiftRows
shift_rows : {n, m : Nat} -> Vect (S n) (Vect m Bits8) -> Vect (S n) (Vect m Bits8)
shift_rows = transpose . shift_rows' Z . transpose

inv_shift_rows' : {m : _} -> Nat -> Vect n (Vect (S m) Bits8) -> Vect n (Vect (S m) Bits8)
inv_shift_rows' n [] = []
inv_shift_rows' n (x :: xs) = inv_rot_word n x :: inv_shift_rows' (S n) xs

||| ShiftRows
inv_shift_rows : {n, m : Nat} -> Vect (S n) (Vect m Bits8) -> Vect (S n) (Vect m Bits8)
inv_shift_rows = transpose . inv_shift_rows' Z . transpose

gmod : Bits8 -> G -> Bits8
gmod x G1 = x
gmod x G2 = (if x < 128 then id else (xor 0x1b)) $ shiftL x 1
gmod x G3 = xor (gmod x G2) x

inv_gmod : Bits8 -> G' -> Bits8
inv_gmod x g =
  index (b8_to_fin x) $ case g of
    G9 => gbox_9
    G11 => gbox_11
    G13 => gbox_13
    G14 => gbox_14

||| MixColumns
mix_columns : Vect n (Vect 4 Bits8) -> Vect n (Vect 4 Bits8)
mix_columns xs = matmul (\a, b => foldl xor 0 $ zipWith gmod a b) xs mix_columns_mat

inv_mix_columns : Vect n (Vect 4 Bits8) -> Vect n (Vect 4 Bits8)
inv_mix_columns xs = matmul (\a, b => foldl xor 0 $ zipWith inv_gmod a b) xs inv_mix_columns_mat

||| Rcon
rcons : Stream Bits8
rcons = go 1
  where
  go : Bits8 -> Stream Bits8
  go x = x :: go ((if x < 0x80 then id else xor (0x1B)) $ 2 * x)

expand_key' : {n_k, n_b : _} -> {auto 0 ok : NonZero n_b} -> Fin n_k -> (rcs : Stream Bits8) -> (prev_block : Vect n_k (Vect n_b Bits8)) -> Stream (Vect n_b Bits8)
expand_key' {n_b = S n_b'} counter (rc :: rcs) (x :: xs) =
  let
    y = last (x :: xs)
  in
    case counter of
      FZ => let z = (vecxor (rc :: replicate _ 0) $ vecxor x $ sub_word $ rot_word 1 $ y) in z :: expand_key' Data.Fin.last rcs (snoc xs z)
      (FS counter') =>
        let
          z = vecxor x $ case isLT 6 n_k of
            Yes wit => if finToNat (FS counter') == 4 then sub_word y else y
            No contra => y
        in
          z :: expand_key' (weaken counter') (rc :: rcs) (snoc xs z)

expand_key : {n_k, n_b : _} -> {auto 0 ok : NonZero n_b} -> {auto 0 ok2 : NonZero n_k} -> Vect n_k (Vect n_b Bits8) -> Stream (Vect n_b Bits8)
expand_key {n_k = S n_k'} k = expand_key' FZ rcons k

mk_round_keys : {n_k, n_b : _} -> {auto 0 ok : NonZero n_b} -> {auto 0 ok2 : NonZero n_k} -> (n_main_rounds : Nat) -> (key : Vect n_k (Vect n_b Bits8)) -> (Vect 4 (Vect n_b Bits8), Vect n_main_rounds (Vect 4 (Vect n_b Bits8)), Vect 4 (Vect n_b Bits8))
mk_round_keys n_main_rounds k =
  let
    (rk_init :: rks) = Stream.take (S (S n_main_rounds)) $ chunk _ $ prepend (toList k) $ expand_key k
  in
    (rk_init, unsnoc rks)

public export
data Mode : Type where
  AES128 : Mode
  AES192 : Mode
  AES256 : Mode

public export
get_n_k : Mode -> Nat
get_n_k AES128 = 4
get_n_k AES192 = 6
get_n_k AES256 = 8

public export
n_k_never_Z : (mode : _) -> NonZero (get_n_k mode)
n_k_never_Z AES128 = SIsNonZero
n_k_never_Z AES192 = SIsNonZero
n_k_never_Z AES256 = SIsNonZero

public export
get_main_rounds : Mode -> Nat
get_main_rounds AES128 = 9
get_main_rounds AES192 = 11
get_main_rounds AES256 = 13

encrypt_block' : {n_k : _} -> {auto 0 ok : NonZero n_k} -> (n_main_rounds : Nat) -> (key : Vect n_k (Vect 4 Bits8)) -> (state : Vect 4 (Vect 4 Bits8)) -> Vect 4 (Vect 4 Bits8)
encrypt_block' n_main_rounds k x =
  let
    (init_rk, main_rks, final_rk) = mk_round_keys n_main_rounds k
    -- initial round
    x = matxor x init_rk
    -- main rounds
    x = foldl (flip $ \rk => matxor rk . mix_columns . shift_rows . sub_bytes) x main_rks
    -- final round
    x = matxor final_rk $ shift_rows $ sub_bytes x
  in
    x

export
encrypt_block : (mode : Mode) -> (key : Vect (get_n_k mode) (Vect 4 Bits8)) -> (state : Vect 4 (Vect 4 Bits8)) -> Vect 4 (Vect 4 Bits8)
encrypt_block mode k s = encrypt_block' {ok = n_k_never_Z mode} (get_main_rounds mode) k s

decrypt_block' : {n_k : _} -> {auto 0 ok : NonZero n_k} -> (n_main_rounds : Nat) -> (key : Vect n_k (Vect 4 Bits8)) -> (state : Vect 4 (Vect 4 Bits8)) -> Vect 4 (Vect 4 Bits8)
decrypt_block' n_main_rounds k x =
  let
    (init_rk, main_rks, final_rk) = mk_round_keys n_main_rounds k
    -- initial round
    x = matxor x init_rk
    -- main rounds
    x = foldl (flip $ \rk => inv_mix_columns . matxor rk . inv_sub_bytes . inv_shift_rows) x main_rks
    -- final round
    x = matxor final_rk $ inv_sub_bytes $ inv_shift_rows x
  in
    x

export
decrypt_block : (mode : Mode) -> (key : Vect (get_n_k mode) (Vect 4 Bits8)) -> (state : Vect 4 (Vect 4 Bits8)) -> Vect 4 (Vect 4 Bits8)
decrypt_block mode k x = decrypt_block' {ok = n_k_never_Z mode} (get_main_rounds mode) k x
