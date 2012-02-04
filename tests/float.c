
sfr at 0x80 sim_ctl_port;
sfr at 0x81 msg_port;
sfr at 0x82 timeout_port;

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

int main ()
{
  float x, y, z;

  for (x=0; x<1.0; x=x+0.1)
    for (y=0; y<1.0; y=y+0.1)
      z=x*y;
  print ("Hello, world!\n");

  sim_ctl_port = 0x01;
  return 0;
}

