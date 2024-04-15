/* Quartus II 64-Bit Version 13.1.0 Build 162 10/23/2013 SJ Web Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Cfg)
		Device PartName(EP4CE6F17) Path("C:/Users/admin/Desktop/DemoBlinkLEDFPGA/output_files/") File("Led_blink.sof") MfrSpec(OpMask(1));
	P ActionCode(Ign)
		Device PartName(EP4CE6) MfrSpec(OpMask(0));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
