/*
 * test_control.h
 *
 *  Created on: Aug 1, 2010
 *      Author: hutch
 */

#ifndef TEST_CONTROL_H_
#define TEST_CONTROL_H_

#define SIM_CTL_PORT 0x80
#define MSG_PORT     0x81
#define TIMEOUT_PORT 0x82

sfr at SIM_CTL_PORT sim_ctl_port;
sfr at MSG_PORT msg_port;
sfr at TIMEOUT_PORT timeout_port;

#define TEST_PASSED 0x01
#define TEST_FAILED 0x02


#endif /* TEST_CONTROL_H_ */
