#!/usr/bin/python
import numpy as np
import matplotlib.pyplot as plt
import os
import struct
import binascii

def load_binary_readout(filename, words=1000, signed=False):
  fsize=os.path.getsize(filename)
  maxwords=fsize/4
  words_to_read=words
  form="I"
  if signed:
    form="i"
  if (words_to_read > maxwords) or words_to_read==0:
    words_to_read=maxwords
  if ".gz" in filename:
    import gzip
    opener=gzip.open
  else:
    opener=open
  with opener(filename, "rb") as f:
    bin_data=f.read(4*words_to_read);
    data=struct.unpack(">"+form*words_to_read, bin_data);

  return np.array(data)

def twos_comp(val, bits):
  if (val & (1 << (bits - 1))) != 0: # if sign bit is set e.g., 8bit: 128-255
    val = val - (1 << bits)        # compute negative value
  return val

def chunks(s, n):
  """Produce `n`-character chunks from `s`."""
  for start in range(0, len(s), n):
    yield s[start:start+n]

def scan_LVDS(fname, bit=2):
  fsize=os.path.getsize(fname)
  f=open(fname, 'rb')
  bin_data=f.read(fsize)
  x_unsigned=[int(binascii.hexlify(x),16) for x in chunks(bin_data,4)][0:]
  bits=[]
  for i, entry in enumerate(x_unsigned):
    bits.append(int(bin(entry)[bit+2]))
  bits=np.array(bits)
  return bits

