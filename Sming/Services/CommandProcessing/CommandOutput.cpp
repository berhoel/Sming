/*
 * CommandOutput.cpp
 *
 *  Created on: 5 jul. 2015
 *      Author: Herman
 */

#include "CommandOutput.h"

CommandOutput::CommandOutput(TcpClient* reqClient)
: outputTcpClient(reqClient)
{
}

CommandOutput::CommandOutput(Stream* reqStream)
: outputStream(reqStream)
{
}

CommandOutput::~CommandOutput()
{
	debugf("destruct");
}

size_t CommandOutput::write(uint8_t outChar)
{
	if (outputTcpClient)
	{
		char outBuf[1] = { outChar };
		outputTcpClient->write(outBuf,1);
	}
	else
	{
		if (outputStream)
		{
			outputStream->write(outChar);
		}
	}
}

