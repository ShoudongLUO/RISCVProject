RISCV_ARCH := rv32im
RISCV_ABI := ilp32
RISCV_MCMODEL := medlow


TARGET = my_adc
LDFLAGS += -Wl,--gc-sections -Wl,--check-sections -lm

#CFLAGS += -DSIMULATION
#CFLAGS += -O2
#ASM_SRCS +=
#LDFLAGS +=
#INCLUDES += -I.

C_SRCS := \
	main.c \


COMMON_DIR = ../../bsp
TOOLCHAIN_DIR = ../../../..
include ../../bsp/common.mk
