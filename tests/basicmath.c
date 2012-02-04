/*
 * basicmath.c
 *
 *  Created on: Aug 1, 2010
 *      Author: hutch
 */

#include "test_control.h"

void nmi_isr() {}
void isr() {}

void print (char *string)
{
  char *iter;

  iter = string;
  while (*iter != 0) {
    msg_port = *iter++;
  }
}

#define CHECK_VAL(v,x) if(v!=x)pass=TEST_FAILED

int main ()
{
  int pass = TEST_PASSED;
  int a, b, c;

  print ("Basic Math\n");

  a = 256;
  b = 512;
  c = a + b;
  CHECK_VAL(c,(256+512));

  b *= 10;
  CHECK_VAL(b,5120);

  a = a >> 2;
  CHECK_VAL(a,64);

  sim_ctl_port = pass;
  return 0;
}

